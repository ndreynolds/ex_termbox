#include <stdbool.h>
#include <stdio.h>

#include "erl_nif.h"
#include "termbox.h"

static bool RUNNING = false;
static bool POLLING = false;
static bool STOP_POLLING = false;
ErlNifResourceType *POLL_STATE_RES_TYPE = NULL;
struct extb_poll_state *POLL_STATE = NULL;

static ERL_NIF_TERM extb_ok(ErlNifEnv *env) {
  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM extb_ok_tuple(ErlNifEnv *env, ERL_NIF_TERM term) {
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), term);
}

static ERL_NIF_TERM extb_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, enif_make_atom(env, "error"),
                          enif_make_atom(env, reason));
}

static ERL_NIF_TERM extb_init(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
  if (RUNNING) {
    return extb_error(env, "already_running");
  }
  RUNNING = true;

  int code = tb_init();
  if (code == 0) {
    return extb_ok(env);
  }
  return enif_make_tuple2(env, enif_make_atom(env, "error"),
                          enif_make_int(env, code));
}

static ERL_NIF_TERM extb_width(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int32_t width = tb_width();
  return extb_ok_tuple(env, enif_make_int(env, width));
}

static ERL_NIF_TERM extb_height(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int32_t height = tb_height();
  return extb_ok_tuple(env, enif_make_int(env, height));
}

static ERL_NIF_TERM extb_clear(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  tb_clear();
  return extb_ok(env);
}

static ERL_NIF_TERM extb_set_clear_attributes(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  unsigned int fg, bg;
  enif_get_uint(env, argv[0], &fg);
  enif_get_uint(env, argv[1], &bg);

  tb_set_clear_attributes((uint32_t)fg, (uint32_t)bg);
  return extb_ok(env);
}

static ERL_NIF_TERM extb_present(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  tb_present();
  return extb_ok(env);
}

static ERL_NIF_TERM extb_set_cursor(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int x, y;
  enif_get_int(env, argv[0], &x);
  enif_get_int(env, argv[1], &y);

  tb_set_cursor(x, y);
  return extb_ok(env);
}

static ERL_NIF_TERM extb_change_cell(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int x, y;
  unsigned int ch, fg, bg;

  enif_get_int(env, argv[0], &x);
  enif_get_int(env, argv[1], &y);
  enif_get_uint(env, argv[2], &ch);
  enif_get_uint(env, argv[3], &fg);
  enif_get_uint(env, argv[4], &bg);

  tb_change_cell(x, y, (uint32_t)ch, (uint16_t)fg, (uint16_t)bg);
  return extb_ok(env);
}

static ERL_NIF_TERM extb_select_input_mode(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int mode, result;
  enif_get_int(env, argv[0], &mode);
  result = tb_select_input_mode(mode);
  return extb_ok_tuple(env, enif_make_int(env, result));
}

static ERL_NIF_TERM extb_select_output_mode(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }

  int mode, result;
  enif_get_int(env, argv[0], &mode);
  result = tb_select_output_mode(mode);
  return extb_ok_tuple(env, enif_make_int(env, result));
}

// Passed to the created thread's function with information on where
// to send the polling result (a local PID) and the thread's id so it
// can later be joined.
struct extb_poll_state {
  ErlNifTid thread_id;
  bool thread_joined;
  ErlNifPid recipient_pid;
};

void *extb_poll_event_run(void *arg) {
  struct extb_poll_state *state = (struct extb_poll_state *)arg;
  struct tb_event *event = enif_alloc(sizeof(struct tb_event));

  int poll_result = 0;

  while (!STOP_POLLING && poll_result == 0) {
    poll_result = tb_peek_event(event, 50);
  }

  if (poll_result > 0) {
    ErlNifEnv *env = enif_alloc_env();
    ERL_NIF_TERM result = enif_make_tuple2(
        env, enif_make_atom(env, "event"),
        enif_make_tuple8(
            env, enif_make_uint(env, event->type),
            enif_make_uint(env, event->mod), enif_make_uint(env, event->key),
            enif_make_uint(env, event->ch), enif_make_int(env, event->w),
            enif_make_int(env, event->h), enif_make_int(env, event->x),
            enif_make_int(env, event->y)));

    // Send the event back to the configured recipient.
    enif_send(NULL, &state->recipient_pid, env, result);
    enif_free_env(env);
  }

  enif_free(event);

  // Release the poll state resource for destruction and gc
  // (BEAM will call `extb_poll_thread_cleanup`)
  enif_release_resource(state);

  // Release the polling lock
  POLLING = false;
  return NULL;
};

void extb_join_poll_thread(struct extb_poll_state *state) {
  if (!state->thread_joined) {
    state->thread_joined = true;
    enif_thread_join(state->thread_id, NULL);
  }
}

void extb_poll_thread_destructor(ErlNifEnv *env, void *arg) {
  struct extb_poll_state *state = (struct extb_poll_state *)arg;
  extb_join_poll_thread(state);
}

static ERL_NIF_TERM extb_poll_event_async(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  // Only one event polling thread may run at a time.
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }
  if (POLLING) {
    return extb_error(env, "already_polling");
  }
  STOP_POLLING = false;
  POLLING = true;

  // Create a resource as a handle for the thread
  struct extb_poll_state *poll_state =
      (struct extb_poll_state *)enif_alloc_resource(
          POLL_STATE_RES_TYPE, sizeof(struct extb_poll_state));
  poll_state->thread_joined = false;

  // Set the recipient pid to the pid arg
  enif_get_local_pid(env, argv[0], &poll_state->recipient_pid);

  POLL_STATE = poll_state;

  // Create a thread to perform the event polling
  int result = enif_thread_create("extb-event-poll", &poll_state->thread_id,
                                  extb_poll_event_run, poll_state, NULL);

  // Returns tuple with the resource for future cleanup
  return enif_make_tuple2(env, enif_make_atom(env, "ok"),
                          enif_make_resource(env, poll_state));
}

static ERL_NIF_TERM extb_cancel_poll_event(ErlNifEnv *env, int argc,
                                           const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }
  if (!POLLING) {
    return extb_error(env, "not_polling");
  }

  if (POLL_STATE) {
    STOP_POLLING = true;
    extb_join_poll_thread(POLL_STATE);
    POLL_STATE = NULL;
  }

  return extb_ok(env);
}

static ERL_NIF_TERM extb_shutdown(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  if (!RUNNING) {
    return extb_error(env, "not_running");
  }
  RUNNING = false;

  if (POLL_STATE) {
    STOP_POLLING = true;
    extb_join_poll_thread(POLL_STATE);
    POLL_STATE = NULL;
  }

  tb_shutdown();
  return extb_ok(env);
}

int extb_load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  // Create a resource type for the poll state
  int flags = ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER;
  const char *resource_type_name = "extb-thread-handler";
  POLL_STATE_RES_TYPE = enif_open_resource_type(
      env, NULL, resource_type_name, extb_poll_thread_destructor, flags, NULL);

  return 0;
}

static ErlNifFunc funcs[] = {
    {"init", 0, extb_init},
    {"width", 0, extb_width},
    {"height", 0, extb_height},
    {"clear", 0, extb_clear},
    {"set_clear_attributes", 2, extb_set_clear_attributes},
    {"present", 0, extb_present},
    {"set_cursor", 2, extb_set_cursor},
    {"change_cell", 5, extb_change_cell},
    {"select_input_mode", 1, extb_select_input_mode},
    {"select_output_mode", 1, extb_select_output_mode},
    {"poll_event", 1, extb_poll_event_async},
    {"cancel_poll_event", 0, extb_cancel_poll_event},
    {"shutdown", 0, extb_shutdown}};

ERL_NIF_INIT(Elixir.ExTermbox.Bindings, funcs, extb_load, NULL, NULL, NULL)
