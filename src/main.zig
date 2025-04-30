const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});
const game = @import("game.zig");

pub fn main() !u8 {
    game.app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status = c.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), game.sdlMainC, null);
    return game.app_err.load() orelse @truncate(@as(c_uint, @bitCast(status)));
}
