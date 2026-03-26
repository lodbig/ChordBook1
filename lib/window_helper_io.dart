import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:window_manager/window_manager.dart';

// ---------------------------------------------------------------------------
// Win32 FFI bindings
// ---------------------------------------------------------------------------

final _user32 = DynamicLibrary.open('user32.dll');

// HWND GetForegroundWindow()
final _getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

// LONG GetWindowLongW(HWND, int)
final _getWindowLong = _user32.lookupFunction<
    Int32 Function(IntPtr hwnd, Int32 nIndex),
    int Function(int hwnd, int nIndex)>('GetWindowLongW');

// LONG SetWindowLongW(HWND, int, LONG)
final _setWindowLong = _user32.lookupFunction<
    Int32 Function(IntPtr hwnd, Int32 nIndex, Int32 dwNewLong),
    int Function(int hwnd, int nIndex, int dwNewLong)>('SetWindowLongW');

// BOOL SetWindowPos(HWND, HWND, int, int, int, int, UINT)
final _setWindowPos = _user32.lookupFunction<
    Int32 Function(IntPtr hwnd, IntPtr hwndInsertAfter, Int32 x, Int32 y,
        Int32 cx, Int32 cy, Uint32 uFlags),
    int Function(int hwnd, int hwndInsertAfter, int x, int y, int cx, int cy,
        int uFlags)>('SetWindowPos');

// GetSystemMetrics
final _getSystemMetrics = _user32.lookupFunction<
    Int32 Function(Int32 nIndex),
    int Function(int nIndex)>('GetSystemMetrics');

// ShowWindow
final _showWindow = _user32.lookupFunction<
    Int32 Function(IntPtr hwnd, Int32 nCmdShow),
    int Function(int hwnd, int nCmdShow)>('ShowWindow');

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _GWL_STYLE = -16;
const _WS_OVERLAPPEDWINDOW = 0x00CF0000;
const _WS_POPUP = 0x80000000;
const _SWP_FRAMECHANGED = 0x0020;
const _SWP_SHOWWINDOW = 0x0040;
const _SWP_NOACTIVATE = 0x0010;
const _HWND_TOP = 0;
const _SM_CXSCREEN = 0;
const _SM_CYSCREEN = 1;
const _SW_MAXIMIZE = 3;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

bool _isFullScreen = false;
int _savedStyle = 0;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

Future<void> initWindow() async {
  if (!Platform.isWindows) return;

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    center: true,
    title: 'ChordBook',
    minimumSize: const ui.Size(800, 500),
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    // קצת delay כדי שהחלון יהיה מוכן לפני שמכניסים למסך מלא
    await Future.delayed(const Duration(milliseconds: 300));
    _enterFullScreen();
  });
}

void onEscPressed() {
  if (!Platform.isWindows) return;
  if (_isFullScreen) _exitFullScreen();
}

void onF11Pressed() {
  if (!Platform.isWindows) return;
  if (_isFullScreen) {
    _exitFullScreen();
  } else {
    _enterFullScreen();
  }
}

// ---------------------------------------------------------------------------
// Win32 fullscreen implementation
// ---------------------------------------------------------------------------

void _enterFullScreen() {
  final hwnd = _getForegroundWindow();
  if (hwnd == 0) return;

  // שמור את הסגנון הנוכחי
  _savedStyle = _getWindowLong(hwnd, _GWL_STYLE);

  // הסר decorations וסט popup style
  _setWindowLong(hwnd, _GWL_STYLE, _WS_POPUP);

  // קבל גודל המסך
  final w = _getSystemMetrics(_SM_CXSCREEN);
  final h = _getSystemMetrics(_SM_CYSCREEN);

  // הגדר את החלון לגודל מלא
  _setWindowPos(hwnd, _HWND_TOP, 0, 0, w, h,
      _SWP_FRAMECHANGED | _SWP_SHOWWINDOW);

  _isFullScreen = true;
}

void _exitFullScreen() {
  final hwnd = _getForegroundWindow();
  if (hwnd == 0) return;

  // שחזר את הסגנון המקורי
  _setWindowLong(hwnd, _GWL_STYLE,
      _savedStyle != 0 ? _savedStyle : _WS_OVERLAPPEDWINDOW);

  _setWindowPos(hwnd, _HWND_TOP, 0, 0, 0, 0,
      _SWP_FRAMECHANGED | _SWP_SHOWWINDOW | _SWP_NOACTIVATE);

  // Maximize כדי לחזור למצב נוח
  _showWindow(hwnd, _SW_MAXIMIZE);

  _isFullScreen = false;
}

Future<bool> confirmAndExit(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('יציאה'),
      content: const Text('האם לצאת מהתוכנה?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ביטול'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('יציאה'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await Hive.close();
    exit(0);
  }
  return false;
}
