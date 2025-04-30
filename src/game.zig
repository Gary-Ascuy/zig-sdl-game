const std = @import("std");

const errors = @import("errors.zig");
const utils = @import("utils.zig");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

// Variables
const sdl_log = std.log.scoped(.sdl);
const app_log = std.log.scoped(.app);

pub var app_err: errors.ErrorStore = .{};

var fully_initialized = false;

const window_w = 640;
const window_h = 480;

var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;

// Methods
pub fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !c.SDL_AppResult {
    _ = appstate;
    _ = argv;

    sdl_log.debug("SDL build time version: {d}.{d}.{d}", .{
        c.SDL_MAJOR_VERSION,
        c.SDL_MINOR_VERSION,
        c.SDL_MICRO_VERSION,
    });

    try errors.errify(c.SDL_Init(c.SDL_INIT_VIDEO));
    sdl_log.debug("SDL video drivers: {}", .{utils.fmtSdlDrivers(
        c.SDL_GetCurrentVideoDriver().?,
        c.SDL_GetNumVideoDrivers(),
        c.SDL_GetVideoDriver,
    )});

    errors.errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};

    try errors.errify(c.SDL_CreateWindowAndRenderer("SDL - Gary Ascuy", window_w, window_h, 0, @ptrCast(&window), @ptrCast(&renderer)));
    errdefer c.SDL_DestroyWindow(window);
    errdefer c.SDL_DestroyRenderer(renderer);

    sdl_log.debug("SDL render drivers: {}", .{utils.fmtSdlDrivers(
        c.SDL_GetRendererName(renderer).?,
        c.SDL_GetNumRenderDrivers(),
        c.SDL_GetRenderDriver,
    )});

    fully_initialized = true;
    errdefer comptime unreachable;

    return c.SDL_APP_CONTINUE;
}

pub fn sdlAppIterate(appstate: ?*anyopaque) !c.SDL_AppResult {
    _ = appstate;

    try errors.errify(c.SDL_SetRenderScale(renderer, 2, 2));
    {
        const gary = "Gary Ascuy was HERE !!!";
        try errors.errify(c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0x00, 0xff));
        try errors.errify(c.SDL_RenderDebugText(renderer, 100, 100, gary.ptr));
    }

    try errors.errify(c.SDL_SetRenderScale(renderer, 1, 1));
    try errors.errify(c.SDL_RenderPresent(renderer));

    return c.SDL_APP_CONTINUE;
}

pub fn sdlAppEvent(appstate: ?*anyopaque, event: *c.SDL_Event) !c.SDL_AppResult {
    _ = appstate;

    switch (event.type) {
        c.SDL_EVENT_QUIT => {
            return c.SDL_APP_SUCCESS;
        },
        else => {},
    }

    return c.SDL_APP_CONTINUE;
}

pub fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!c.SDL_AppResult) void {
    _ = appstate;

    _ = result catch |err| if (err == error.SdlError) {
        sdl_log.err("{s}", .{c.SDL_GetError()});
    };

    if (fully_initialized) {
        c.SDL_DestroyRenderer(renderer);
        c.SDL_DestroyWindow(window);
        fully_initialized = false;
    }
}

pub fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return c.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

pub fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

pub fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) c.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

pub fn sdlAppEventC(appstate: ?*anyopaque, event: ?*c.SDL_Event) callconv(.c) c.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

pub fn sdlAppQuitC(appstate: ?*anyopaque, result: c.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}
