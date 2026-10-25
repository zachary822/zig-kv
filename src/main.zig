const std = @import("std");
const httpz = @import("httpz");
const bpt = @import("bplustree");
const Io = std.Io;

const zig_kv = @import("zig_kv");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const file = try Io.Dir.cwd().createFile(io, "data.db", .{ .read = true, .truncate = false });
    defer file.close(io);
    const log = try Io.Dir.cwd().createFile(io, "data.db.wal", .{ .read = true, .truncate = false });
    defer log.close(io);

    var db: bpt.BPTree = try .init(gpa, io, file, log);
    defer db.deinit();

    _ = try db.vacuum(.full);

    var app: App = .{ .db = &db };

    var server = try httpz.Server(*App).init(io, gpa, .{
        .address = .localhost(8000),
    }, &app);
    defer {
        server.stop();
        server.deinit();
        db.sync() catch {};
    }

    var router = try server.router(.{});
    router.get("/:key", getKey, .{});
    router.post("/:key", putKey, .{});

    std.log.info("listening on {f}", .{server.config.address.ip});
    try server.listen();
}

const App = struct {
    db: *bpt.BPTree,
};

fn getKey(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const key = req.param("key").?;
    if (key.len > bpt.max_key) {
        res.status = 400;
        res.body = "Key Too Long";
        return;
    }

    const out = try app.db.getAlloc(res.arena, key) orelse {
        res.status = 404;
        res.body = "Not Found";
        return;
    };

    res.status = 200;
    res.body = out;
    return;
}

fn putKey(app: *App, req: *httpz.Request, res: *httpz.Response) !void {
    const key = req.param("key").?;
    if (key.len > bpt.max_key) {
        res.status = 400;
        res.body = "Key Too Long";
        return;
    }
    const body = req.body() orelse {
        res.status = 400;
        res.body = "Bad Request";
        return;
    };
    try app.db.put(key, body);
    res.status = 201;
    return;
}
