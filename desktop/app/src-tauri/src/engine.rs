//! Connection to the analysis engine (MATLAB now, Python later).
//!
//! The app listens on 127.0.0.1:<random port>. The engine connects as a TCP client and
//! introduces itself with an `engine.hello` notification carrying a one-time token.
//! After that both sides exchange JSON-RPC 2.0 messages, one JSON object per line.
//!
//! Modes:
//! - `launch`: the app starts `matlab -batch "cd(engineDir); actipass_engine(port, token)"`.
//! - `compiled`: the app starts the compiled engine `actipass_engine.exe <port> <token>`
//!   (MATLAB Runtime, installed by the engine installer; see `compiled_exe`).
//! - `attach`: the app only listens; the user runs the attach command in their own MATLAB
//!   (debugging with breakpoints). A restarted engine can reconnect with the same command.
//!
//! Events to the front end: `engine-status` (EngineStatus), `engine-notification`
//! ({method, params}: progress, log, ...), `engine-output` ({stream, line}: MATLAB stdout/stderr).
//!
//! SPDX-License-Identifier: GPL-3.0-or-later

use std::collections::HashMap;
use std::path::{Component, PathBuf};
use std::process::Stdio;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde::Serialize;
use serde_json::{json, Value};
use tauri::async_runtime::JoinHandle;
use tauri::{AppHandle, Emitter};
use tokio::io::{AsyncBufReadExt, AsyncRead, AsyncWriteExt, BufReader};
use tokio::net::tcp::OwnedWriteHalf;
use tokio::net::TcpListener;
use tokio::process::{Child, Command};
use tokio::sync::{oneshot, Mutex as AsyncMutex};

const HELLO_TIMEOUT: Duration = Duration::from_secs(10);
const HEARTBEAT: Duration = Duration::from_secs(10);

#[derive(Clone, Serialize, Default, Debug)]
#[serde(rename_all = "camelCase")]
pub struct EngineStatus {
    /// stopped | waiting | connected | disconnected | failed
    pub state: String,
    /// "" | launch | compiled | attach
    pub mode: String,
    /// program started for the engine (launch / compiled modes)
    pub program: String,
    pub port: u16,
    /// MATLAB command that connects an engine to this app (attach mode)
    pub attach_command: String,
    pub engine_dir: String,
    /// params of the engine.hello notification (without the token)
    pub hello: Value,
    pub last_error: String,
}

#[derive(Default)]
struct Inner {
    status: Mutex<EngineStatus>,
    token: Mutex<String>,
    writer: AsyncMutex<Option<OwnedWriteHalf>>,
    pending: Mutex<HashMap<u64, oneshot::Sender<Value>>>,
    next_id: AtomicU64,
    child: Mutex<Option<Child>>,
    tasks: Mutex<Vec<JoinHandle<()>>>,
}

#[derive(Default, Clone)]
pub struct Engine {
    inner: Arc<Inner>,
}

impl Engine {
    pub fn status(&self) -> EngineStatus {
        let mut st = self.inner.status.lock().unwrap().clone();
        if st.state.is_empty() {
            st.state = "stopped".into(); // never started
        }
        st
    }

    fn set_status(&self, app: &AppHandle, f: impl FnOnce(&mut EngineStatus)) {
        let snapshot = {
            let mut st = self.inner.status.lock().unwrap();
            f(&mut st);
            st.clone()
        };
        let _ = app.emit("engine-status", snapshot);
    }

    fn spawn(&self, fut: impl std::future::Future<Output = ()> + Send + 'static) {
        let h = tauri::async_runtime::spawn(fut);
        self.inner.tasks.lock().unwrap().push(h);
    }

    /// Start listening and start MATLAB (mode "launch") or the compiled engine ("compiled").
    pub async fn start(
        &self,
        app: AppHandle,
        mode: &str,
        matlab: Option<String>,
        exe: Option<String>,
    ) -> Result<EngineStatus, String> {
        self.stop(&app).await;

        let listener = TcpListener::bind("127.0.0.1:0").await.map_err(|e| format!("Cannot listen on localhost: {e}"))?;
        let port = listener.local_addr().map_err(|e| e.to_string())?.port();
        let token = uuid::Uuid::new_v4().simple().to_string();
        *self.inner.token.lock().unwrap() = token.clone();

        let engine_dir = engine_dir();
        let dir_str = engine_dir.to_string_lossy().to_string();
        let attach_command = format!(
            "cd('{}'); actipass_engine({}, '{}')",
            dir_str.replace('\'', "''"),
            port,
            token
        );

        self.set_status(&app, |s| {
            *s = EngineStatus {
                state: "waiting".into(),
                mode: mode.into(),
                port,
                attach_command: attach_command.clone(),
                engine_dir: dir_str.clone(),
                program: String::new(),
                hello: Value::Null,
                last_error: String::new(),
            }
        });

        // accept loop: one engine at a time; a disconnected engine may reconnect
        let me = self.clone();
        let app2 = app.clone();
        self.spawn(async move { me.accept_loop(app2, listener, token).await });

        // heartbeat keeps the engine's idle timeout from stopping it
        let me = self.clone();
        let app2 = app.clone();
        self.spawn(async move {
            loop {
                tokio::time::sleep(HEARTBEAT).await;
                if me.status().state == "connected" {
                    let _ = tokio::time::timeout(Duration::from_secs(30), me.request(&app2, "engine.ping", json!({}))).await;
                }
            }
        });

        let launched = match mode {
            "launch" => {
                let matlab = matlab.unwrap_or_else(|| "matlab".into());
                self.launch(&app, &matlab, &["-batch".into(), attach_command.clone()], "MATLAB")
            }
            "compiled" => match exe.map(PathBuf::from).or_else(compiled_exe) {
                Some(p) => {
                    let args = [port.to_string(), self.inner.token.lock().unwrap().clone()];
                    self.launch(&app, &p.to_string_lossy(), &args, "Engine")
                }
                None => Err("Compiled engine not found: install the Actipass engine or choose actipass_engine.exe".into()),
            },
            _ => Ok(()),
        };
        if let Err(e) = launched {
            self.set_status(&app, |s| {
                s.state = "failed".into();
                s.last_error = e.clone();
            });
            return Err(e);
        }
        Ok(self.status())
    }

    fn launch(&self, app: &AppHandle, program: &str, args: &[String], label: &'static str) -> Result<(), String> {
        self.set_status(app, |s| s.program = program.to_string());
        let mut cmd = Command::new(program);
        cmd.args(args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .kill_on_drop(true);
        #[cfg(windows)]
        cmd.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
        let mut child = cmd.spawn().map_err(|e| format!("Cannot start {label} ({program}): {e}"))?;

        if let Some(out) = child.stdout.take() {
            let app2 = app.clone();
            self.spawn(async move { forward_output(app2, out, "stdout").await });
        }
        if let Some(err) = child.stderr.take() {
            let app2 = app.clone();
            self.spawn(async move { forward_output(app2, err, "stderr").await });
        }
        *self.inner.child.lock().unwrap() = Some(child);

        // report when MATLAB exits
        let me = self.clone();
        let app2 = app.clone();
        self.spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_millis(500)).await;
                let exited = {
                    let mut guard = me.inner.child.lock().unwrap();
                    match guard.as_mut().map(|c| c.try_wait()) {
                        Some(Ok(Some(code))) => {
                            *guard = None;
                            Some(code.to_string())
                        }
                        Some(Err(e)) => Some(e.to_string()),
                        _ => None,
                    }
                };
                if let Some(code) = exited {
                    if me.status().state != "connected" {
                        me.set_status(&app2, |s| {
                            s.state = "failed".into();
                            s.last_error = format!("{label} exited ({code}) before the engine connected");
                        });
                    }
                    let _ = app2.emit("engine-output", json!({"stream": "system", "line": format!("{label} exited: {code}")}));
                    break;
                }
            }
        });
        Ok(())
    }

    async fn accept_loop(&self, app: AppHandle, listener: TcpListener, token: String) {
        loop {
            let Ok((stream, _)) = listener.accept().await else { continue };
            let (rd, wr) = stream.into_split();
            let mut lines = BufReader::new(rd).lines();

            // the first message must be engine.hello with our token
            let hello = match tokio::time::timeout(HELLO_TIMEOUT, lines.next_line()).await {
                Ok(Ok(Some(line))) => serde_json::from_str::<Value>(&line).ok(),
                _ => None,
            };
            let Some(hello) = hello.filter(|m| {
                m["method"] == "engine.hello" && m["params"]["token"].as_str() == Some(token.as_str())
            }) else {
                continue; // not our engine: drop the connection
            };
            let mut params = hello["params"].clone();
            if let Some(obj) = params.as_object_mut() {
                obj.remove("token");
            }

            *self.inner.writer.lock().await = Some(wr);
            self.set_status(&app, |s| {
                s.state = "connected".into();
                s.hello = params;
                s.last_error.clear();
            });

            while let Ok(Some(line)) = lines.next_line().await {
                self.handle_line(&app, &line);
            }

            // connection closed
            *self.inner.writer.lock().await = None;
            self.inner.pending.lock().unwrap().clear(); // waiting requests get "disconnected"
            self.set_status(&app, |s| {
                s.state = "disconnected".into();
                s.hello = Value::Null;
            });
        }
    }

    fn handle_line(&self, app: &AppHandle, line: &str) {
        let Ok(msg) = serde_json::from_str::<Value>(line) else {
            let _ = app.emit("engine-output", json!({"stream": "system", "line": format!("unparsable engine message: {line}")}));
            return;
        };
        if msg.get("method").is_none() {
            // response to one of our requests
            if let Some(id) = msg.get("id").and_then(Value::as_u64) {
                if let Some(tx) = self.inner.pending.lock().unwrap().remove(&id) {
                    let _ = tx.send(msg);
                }
            }
            return;
        }
        let _ = app.emit("engine-notification", json!({"method": msg["method"], "params": msg["params"]}));
    }

    /// Send a request and wait for its response. Err carries the JSON-RPC error object
    /// ({code, message, data?}); code -32002 = not connected, -32003 = disconnected.
    pub async fn request(&self, _app: &AppHandle, method: &str, params: Value) -> Result<Value, Value> {
        let id = self.inner.next_id.fetch_add(1, Ordering::Relaxed) + 1;
        let (tx, rx) = oneshot::channel();
        self.inner.pending.lock().unwrap().insert(id, tx);
        let line = json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params}).to_string() + "\n";

        let sent = {
            let mut w = self.inner.writer.lock().await;
            match w.as_mut() {
                Some(w) => w.write_all(line.as_bytes()).await.map_err(|e| e.to_string()),
                None => Err("Engine not connected".to_string()),
            }
        };
        if let Err(e) = sent {
            self.inner.pending.lock().unwrap().remove(&id);
            return Err(json!({"code": -32002, "message": e}));
        }

        match rx.await {
            Ok(msg) => match msg.get("error") {
                Some(err) => Err(err.clone()),
                None => Ok(msg.get("result").cloned().unwrap_or(Value::Null)),
            },
            Err(_) => Err(json!({"code": -32003, "message": "Engine disconnected"})),
        }
    }

    /// Ask the engine to stop, then end all tasks and MATLAB.
    pub async fn stop(&self, app: &AppHandle) {
        if self.status().state == "connected" {
            let _ = tokio::time::timeout(Duration::from_secs(3), self.request(app, "engine.shutdown", json!({}))).await;
        }
        for h in self.inner.tasks.lock().unwrap().drain(..) {
            h.abort();
        }
        *self.inner.writer.lock().await = None;
        self.inner.pending.lock().unwrap().clear();
        if let Some(mut child) = self.inner.child.lock().unwrap().take() {
            let _ = child.start_kill();
        }
        if self.status().state != "stopped" && !self.status().state.is_empty() {
            self.set_status(app, |s| {
                s.state = "stopped".into();
                s.hello = Value::Null;
            });
        }
    }
}

async fn forward_output(app: AppHandle, stream: impl AsyncRead + Unpin, name: &'static str) {
    let mut lines = BufReader::new(stream).lines();
    while let Ok(Some(line)) = lines.next_line().await {
        let _ = app.emit("engine-output", json!({"stream": name, "line": line}));
    }
}

/// Folder with actipass_engine.m: $ACTIPASS_ENGINE_DIR, else <repo>/engine-matlab
/// (development builds; release builds will bundle a compiled engine).
fn engine_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("ACTIPASS_ENGINE_DIR") {
        return PathBuf::from(dir);
    }
    normalize(PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..").join("..").join("engine-matlab"))
}

/// The compiled engine: $ACTIPASS_ENGINE_EXE, else the engine installer's default folder
/// (%ProgramFiles%\Ergo-Tools\Actipass Engine\application\actipass_engine.exe), else in
/// development builds the newest engine-matlab/build/<version>/exe/actipass_engine.exe.
pub fn compiled_exe() -> Option<PathBuf> {
    let exe_name = if cfg!(windows) { "actipass_engine.exe" } else { "actipass_engine" };
    let mut candidates: Vec<PathBuf> = Vec::new();
    if let Ok(p) = std::env::var("ACTIPASS_ENGINE_EXE") {
        candidates.push(PathBuf::from(p));
    }
    if let Ok(pf) = std::env::var("ProgramFiles") {
        candidates.push(PathBuf::from(pf).join("Ergo-Tools").join("Actipass Engine").join("application").join(exe_name));
    }
    if cfg!(debug_assertions) {
        if let Ok(rd) = std::fs::read_dir(engine_dir().join("build")) {
            let mut builds: Vec<PathBuf> = rd
                .filter_map(|e| e.ok().map(|e| e.path().join("exe").join(exe_name)))
                .filter(|p| p.is_file())
                .collect();
            builds.sort_by_key(|p| std::fs::metadata(p).and_then(|m| m.modified()).ok());
            candidates.extend(builds.into_iter().rev());
        }
    }
    candidates.into_iter().find(|p| p.is_file())
}

/// Remove `.` and `..` without touching the file system (canonicalize adds \\?\ on Windows).
fn normalize(p: PathBuf) -> PathBuf {
    let mut out = PathBuf::new();
    for c in p.components() {
        match c {
            Component::ParentDir => {
                out.pop();
            }
            Component::CurDir => {}
            other => out.push(other.as_os_str()),
        }
    }
    out
}

// ------------------------------------------------------------------ Tauri commands

#[tauri::command]
pub async fn engine_start(
    app: AppHandle,
    engine: tauri::State<'_, Engine>,
    mode: String,
    matlab: Option<String>,
    exe: Option<String>,
) -> Result<EngineStatus, String> {
    if !["launch", "compiled", "attach"].contains(&mode.as_str()) {
        return Err(format!("unknown engine mode: {mode}"));
    }
    let nonempty = |s: Option<String>| s.filter(|m| !m.trim().is_empty());
    engine.start(app, &mode, nonempty(matlab), nonempty(exe)).await
}

/// Where the compiled engine was found (null if not installed) and whether this is a
/// development build (development defaults to MATLAB, release to the compiled engine).
#[tauri::command]
pub fn engine_info(app: AppHandle) -> Value {
    json!({
        "appVersion": app.package_info().version.to_string(),
        "compiledExe": compiled_exe().map(|p| p.to_string_lossy().to_string()),
        "devBuild": cfg!(debug_assertions),
        "engineDir": engine_dir().to_string_lossy(),
    })
}

#[tauri::command]
pub async fn engine_stop(app: AppHandle, engine: tauri::State<'_, Engine>) -> Result<EngineStatus, String> {
    engine.stop(&app).await;
    Ok(engine.status())
}

#[tauri::command]
pub fn engine_status(engine: tauri::State<'_, Engine>) -> EngineStatus {
    engine.status()
}

#[tauri::command]
pub async fn engine_request(
    app: AppHandle,
    engine: tauri::State<'_, Engine>,
    method: String,
    params: Option<Value>,
) -> Result<Value, Value> {
    engine.request(&app, &method, params.unwrap_or_else(|| json!({}))).await
}
