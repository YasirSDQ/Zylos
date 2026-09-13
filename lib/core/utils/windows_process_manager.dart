import 'dart:ffi';
import 'dart:io';

class WindowsProcessManager {
  static void suspendProcess(int pid) {
    if (!Platform.isWindows) return;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final ntdll = DynamicLibrary.open('ntdll.dll');
      
      final openProcess = kernel32.lookupFunction<
          Pointer Function(Uint32, Int32, Uint32),
          Pointer Function(int, int, int)>('OpenProcess');
          
      final closeHandle = kernel32.lookupFunction<
          Int32 Function(Pointer),
          int Function(Pointer)>('CloseHandle');
          
      final ntSuspendProcess = ntdll.lookupFunction<
          Int32 Function(Pointer),
          int Function(Pointer)>('NtSuspendProcess');
      
      // PROCESS_SUSPEND_RESUME = 0x0800
      final handle = openProcess(0x0800, 0, pid);
      if (handle.address != 0) {
        ntSuspendProcess(handle);
        closeHandle(handle);
      }
    } catch (e) {
      print('Failed to suspend process: $e');
    }
  }

  static void resumeProcess(int pid) {
    if (!Platform.isWindows) return;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final ntdll = DynamicLibrary.open('ntdll.dll');
      
      final openProcess = kernel32.lookupFunction<
          Pointer Function(Uint32, Int32, Uint32),
          Pointer Function(int, int, int)>('OpenProcess');
          
      final closeHandle = kernel32.lookupFunction<
          Int32 Function(Pointer),
          int Function(Pointer)>('CloseHandle');
          
      final ntResumeProcess = ntdll.lookupFunction<
          Int32 Function(Pointer),
          int Function(Pointer)>('NtResumeProcess');
      
      // PROCESS_SUSPEND_RESUME = 0x0800
      final handle = openProcess(0x0800, 0, pid);
      if (handle.address != 0) {
        ntResumeProcess(handle);
        closeHandle(handle);
      }
    } catch (e) {
      print('Failed to resume process: $e');
    }
  }
}
