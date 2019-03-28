#[macro_use]
extern crate rustler;
extern crate libc;

use std::sync::atomic::{AtomicBool, Ordering};

use libc::c_int;

use rustler::thread;
use rustler::types::Pid;
use rustler::{Encoder, Env, NifResult, Term};

static RUNNING: AtomicBool = AtomicBool::new(false);
static POLLING: AtomicBool = AtomicBool::new(false);
static STOP_POLLING: AtomicBool = AtomicBool::new(false);

#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct tb_event {
    pub type_: u8,
    pub mod_: u8,
    pub key: u16,
    pub ch: u32,
    pub w: i32,
    pub h: i32,
    pub x: i32,
    pub y: i32,
}

#[link(name = "termbox", kind = "static")]
extern "C" {
    fn tb_init() -> c_int;
    fn tb_shutdown() -> ();
    fn tb_width() -> c_int;
    fn tb_height() -> c_int;
    fn tb_clear() -> ();
    fn tb_set_clear_attributes(fg: u16, bg: u16) -> ();
    fn tb_present() -> ();
    fn tb_set_cursor(x: c_int, y: c_int) -> ();
    fn tb_change_cell(x: c_int, y: c_int, ch: c_int, fg: u16, bg: u16) -> ();
    fn tb_select_input_mode(mode: c_int) -> c_int;
    fn tb_select_output_mode(mode: c_int) -> c_int;
    fn tb_peek_event(event: *mut tb_event, timeout: u16) -> c_int;
}

mod atoms {
    rustler_atoms! {
        atom ok;
        atom error;
        atom not_running;
        atom not_polling;
        atom already_running;
        atom already_polling;
    }
}

rustler_export_nifs! {
    "Elixir.ExTermbox.Bindings",
    [
        ("init", 0, init),
        ("shutdown", 0, shutdown),
        ("width", 0, width),
        ("height", 0, height),
        ("clear", 0, clear),
        ("set_clear_attributes", 2, set_clear_attributes),
        ("present", 0, present),
        ("set_cursor", 2, set_cursor),
        ("change_cell", 5, change_cell),
        ("select_input_mode", 1, select_input_mode),
        ("select_output_mode", 1, select_output_mode),
        ("start_polling", 1, start_polling),
        ("stop_polling", 0, stop_polling),
    ],
    None
}

fn init<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if is_running() {
        return Ok(env.error_tuple(atoms::already_running()));
    }

    RUNNING.store(true, Ordering::SeqCst);

    let _code = unsafe { tb_init() };

    // TODO: handle error codes

    Ok(atoms::ok().encode(env))
}

fn shutdown<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    RUNNING.store(false, Ordering::SeqCst);

    unsafe { tb_shutdown() };

    Ok(atoms::ok().encode(env))
}

fn width<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let width = unsafe { tb_width() };

    Ok((atoms::ok(), width).encode(env))
}

fn height<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let height = unsafe { tb_height() };

    Ok((atoms::ok(), height).encode(env))
}

fn clear<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    unsafe { tb_clear() };

    Ok(atoms::ok().encode(env))
}

fn set_clear_attributes<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let fg: u16 = args[0].decode()?;
    let bg: u16 = args[1].decode()?;

    unsafe { tb_set_clear_attributes(fg, bg) };

    Ok(atoms::ok().encode(env))
}

fn present<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    unsafe { tb_present() };

    Ok(atoms::ok().encode(env))
}

fn set_cursor<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let x: i32 = args[0].decode()?;
    let y: i32 = args[1].decode()?;

    unsafe { tb_set_cursor(x, y) };

    Ok(atoms::ok().encode(env))
}

fn change_cell<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let x: i32 = args[0].decode()?;
    let y: i32 = args[1].decode()?;
    let ch: i32 = args[2].decode()?;
    let fg: u16 = args[3].decode()?;
    let bg: u16 = args[4].decode()?;

    unsafe { tb_change_cell(x, y, ch, fg, bg) };

    Ok(atoms::ok().encode(env))
}

fn select_input_mode<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let mode: i32 = args[0].decode()?;

    let new_mode = unsafe { tb_select_input_mode(mode) };

    Ok((atoms::ok(), new_mode).encode(env))
}

fn select_output_mode<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }

    let mode: i32 = args[0].decode()?;

    let new_mode = unsafe { tb_select_output_mode(mode) };

    Ok((atoms::ok(), new_mode).encode(env))
}

fn start_polling<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }
    if is_polling() {
        return Ok(env.error_tuple(atoms::already_polling()));
    }

    POLLING.store(true, Ordering::SeqCst);

    let recipient: Pid = args[0].decode()?;

    let _term = thread::spawn::<thread::ThreadSpawner, _>(env, move |thread_env| {
        let event = &mut tb_event {
            x: 0,
            y: 0,
            ch: 0,
            h: 0,
            w: 0,
            key: 0,
            type_: 0,
            mod_: 0,
        };

        let mut poll_result = 0;

        while !stop_polling_signaled() && poll_result >= 0 {
            poll_result = unsafe { tb_peek_event(event, 10) };

            let message = (
                        event.type_,
                        event.mod_,
                        event.key,
                        event.ch,
                        (event.w, event.h),
                        (event.x, event.y),
                    );

            if poll_result > 0 {
                thread_env.send(&recipient, message.encode(thread_env));
            }
        }

        POLLING.store(false, Ordering::SeqCst);
        STOP_POLLING.store(false, Ordering::SeqCst);

        atoms::ok().encode(thread_env)
    });

    Ok((atoms::ok(), 42).encode(env))
}

fn stop_polling<'a>(env: Env<'a>, _args: &[Term<'a>]) -> NifResult<Term<'a>> {
    if !is_running() {
        return Ok(env.error_tuple(atoms::not_running()));
    }
    if !is_polling() {
        return Ok(env.error_tuple(atoms::not_polling()));
    }

    STOP_POLLING.store(true, Ordering::SeqCst);

    while is_polling() {}

    Ok(atoms::ok().encode(env))
}

fn is_running() -> bool {
    RUNNING.load(Ordering::SeqCst)
}

fn is_polling() -> bool {
    POLLING.load(Ordering::SeqCst)
}

fn stop_polling_signaled() -> bool {
    POLLING.load(Ordering::SeqCst)
}
