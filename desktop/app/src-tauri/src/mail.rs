// SPDX-License-Identifier: GPL-3.0-or-later
//
// A new mail with an attachment in the user's default mail program (licence requests).
// Windows: Simple MAPI (MAPISendMailW from mapi32.dll), which programs such as classic Outlook
// and Thunderbird provide when they are the default mail client. The mail opens for the user
// to check and send; nothing is sent without them. When there is no MAPI mail client (e.g.
// web mail, the new Outlook) the command fails and the UI falls back to a mailto: link
// without the attachment. Other systems: not supported (the UI uses the fallback).

#[tauri::command]
pub async fn mail_with_attachment(
    to: Vec<String>,
    cc: Vec<String>,
    subject: String,
    body: String,
    attachment: String,
) -> Result<String, String> {
    tauri::async_runtime::spawn_blocking(move || send(&to, &cc, &subject, &body, &attachment))
        .await
        .map_err(|e| e.to_string())?
}

#[cfg(not(windows))]
fn send(_: &[String], _: &[String], _: &str, _: &str, _: &str) -> Result<String, String> {
    Err("not supported on this system".into())
}

#[cfg(windows)]
fn send(to: &[String], cc: &[String], subject: &str, body: &str, attachment: &str) -> Result<String, String> {
    use std::ffi::c_void;
    use std::ptr::null_mut;

    #[repr(C)]
    struct MapiRecipDescW {
        reserved: u32,
        recip_class: u32,
        name: *mut u16,
        address: *mut u16,
        eid_size: u32,
        entry_id: *mut c_void,
    }
    #[repr(C)]
    struct MapiFileDescW {
        reserved: u32,
        flags: u32,
        position: u32,
        path_name: *mut u16,
        file_name: *mut u16,
        file_type: *mut c_void,
    }
    #[repr(C)]
    struct MapiMessageW {
        reserved: u32,
        subject: *mut u16,
        note_text: *mut u16,
        message_type: *mut u16,
        date_received: *mut u16,
        conversation_id: *mut u16,
        flags: u32,
        originator: *mut MapiRecipDescW,
        recip_count: u32,
        recips: *mut MapiRecipDescW,
        file_count: u32,
        files: *mut MapiFileDescW,
    }
    type SendMailW = unsafe extern "system" fn(usize, usize, *mut MapiMessageW, u32, u32) -> u32;
    unsafe extern "system" {
        fn LoadLibraryW(name: *const u16) -> *mut c_void;
        fn GetProcAddress(module: *mut c_void, name: *const u8) -> *mut c_void;
    }
    const MAPI_TO: u32 = 1;
    const MAPI_CC: u32 = 2;
    const MAPI_LOGON_UI: u32 = 0x1;
    const MAPI_DIALOG: u32 = 0x8;
    const MAPI_USER_ABORT: u32 = 1;

    fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }

    if !std::path::Path::new(attachment).is_file() {
        return Err(format!("file not found: {attachment}"));
    }
    // UTF-16 strings live until the call returns
    let mut subject_w = wide(subject);
    let mut body_w = wide(body);
    let mut path_w = wide(attachment);
    let file_name = std::path::Path::new(attachment).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
    let mut file_name_w = wide(&file_name);
    let mut addrs: Vec<(u32, Vec<u16>, Vec<u16>)> = to.iter().map(|a| (MAPI_TO, a))
        .chain(cc.iter().map(|a| (MAPI_CC, a)))
        .map(|(class, a)| (class, wide(a), wide(&format!("SMTP:{a}"))))
        .collect();
    let mut recips: Vec<MapiRecipDescW> = addrs.iter_mut().map(|(class, name, addr)| MapiRecipDescW {
        reserved: 0,
        recip_class: *class,
        name: name.as_mut_ptr(),
        address: addr.as_mut_ptr(),
        eid_size: 0,
        entry_id: null_mut(),
    }).collect();
    let mut file = MapiFileDescW {
        reserved: 0,
        flags: 0,
        position: u32::MAX, // no position in the text
        path_name: path_w.as_mut_ptr(),
        file_name: file_name_w.as_mut_ptr(),
        file_type: null_mut(),
    };
    let mut msg = MapiMessageW {
        reserved: 0,
        subject: subject_w.as_mut_ptr(),
        note_text: body_w.as_mut_ptr(),
        message_type: null_mut(),
        date_received: null_mut(),
        conversation_id: null_mut(),
        flags: 0,
        originator: null_mut(),
        recip_count: recips.len() as u32,
        recips: if recips.is_empty() { null_mut() } else { recips.as_mut_ptr() },
        file_count: 1,
        files: &mut file,
    };
    unsafe {
        let lib = LoadLibraryW(wide("mapi32.dll").as_ptr());
        if lib.is_null() {
            return Err("no MAPI mail client (mapi32.dll not found)".into());
        }
        let f = GetProcAddress(lib, b"MAPISendMailW\0".as_ptr());
        if f.is_null() {
            return Err("no MAPI mail client (MAPISendMailW not found)".into());
        }
        let send_mail: SendMailW = std::mem::transmute(f);
        match send_mail(0, 0, &mut msg, MAPI_LOGON_UI | MAPI_DIALOG, 0) {
            0 => Ok("opened".into()),
            MAPI_USER_ABORT => Ok("closed".into()),
            code => Err(format!("the mail program could not be opened (MAPI error {code})")),
        }
    }
}
