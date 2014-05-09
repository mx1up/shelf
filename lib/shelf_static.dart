library shelf_static;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

// directory listing
// default document
// sym links
// mime type handling
// hidden files

// If-Modified-Since on request

Handler getHandler(String fileSystemPath) {
  var rootDir = new Directory(fileSystemPath);
  fileSystemPath = rootDir.resolveSymbolicLinksSync();

  return (Request request) {
    // TODO: expand these checks and/or follow updates to Uri class to be more
    //       strict. https://code.google.com/p/dart/issues/detail?id=16081
    if (request.requestedUri.path.contains(' ')) {
      return new Response.forbidden('The requested path is invalid.');
    }

    var segs = [fileSystemPath]..addAll(request.url.pathSegments);

    var requestedPath = p.joinAll(segs);
    var file = new File(requestedPath);

    if (!file.existsSync()) {
      return new Response.notFound('Not Found');
    }

    var resolvedPath = file.resolveSymbolicLinksSync();

    // Do not serve a file outside of the original fileSystemPath
    if (!p.isWithin(fileSystemPath, resolvedPath)) {
      // TODO(kevmoo) throw a real error here. Perhaps a new error type?
      throw 'Requested path ${request.url.path} resolved to $resolvedPath '
          'is not under $fileSystemPath.';
    }

    var fileStat = file.statSync();

    var headers = <String, String>{
      HttpHeaders.CONTENT_LENGTH: fileStat.size.toString(),
      HttpHeaders.LAST_MODIFIED: _formatHttpDate(fileStat.changed)
    };

    return new Response.ok(file.openRead(), headers: headers);
  };
}

const _WEEKDAYS = const ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const _MONTHS = const ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
    "Sep", "Oct", "Nov", "Dec"];

// TODO(kevmoo) remove once http_parser fix
// https://codereview.chromium.org/278783002/ is landed
String _formatHttpDate(DateTime date) {
  date = date.toUtc();
  var buffer = new StringBuffer()
      ..write(_WEEKDAYS[date.weekday - 1])
      ..write(", ")
      ..write(date.day <= 9 ? "0" : "")
      ..write(date.day.toString())
      ..write(" ")
      ..write(_MONTHS[date.month - 1])
      ..write(" ")
      ..write(date.year.toString())
      ..write(date.hour <= 9 ? " 0" : " ")
      ..write(date.hour.toString())
      ..write(date.minute <= 9 ? ":0" : ":")
      ..write(date.minute.toString())
      ..write(date.second <= 9 ? ":0" : ":")
      ..write(date.second.toString())
      ..write(" GMT");
  return buffer.toString();
}
