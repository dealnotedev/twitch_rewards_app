import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class ProcessInfo {
  final String name;

  final int processId;

  ProcessInfo(this.name, this.processId);
}

class ProcessFinder {
  /// Initializes the class.
  static void initialize() {
    // Initialize COM
    var hr = CoInitializeEx(nullptr, COINIT.COINIT_MULTITHREADED);
    if (FAILED(hr)) {
      throw COMException(hr);
    }

    // Initialize security model
    hr = CoInitializeSecurity(
        nullptr,
        -1,
        // COM negotiates service
        nullptr,
        // Authentication services
        nullptr,
        // Reserved
        RPC_C_AUTHN_LEVEL.RPC_C_AUTHN_LEVEL_DEFAULT,
        // authentication
        RPC_C_IMP_LEVEL.RPC_C_IMP_LEVEL_IMPERSONATE,
        // Impersonation
        nullptr,
        // Authentication info
        EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE,
        // Additional capabilities
        nullptr // Reserved
        );

    if (FAILED(hr)) {
      // If RPC_E_TOO_LATE, we don't have to bail; CoInititializeSecurity() can
      // only be called once per process.
      if (hr != RPC_E_TOO_LATE) {
        final exception = COMException(hr);

        CoUninitialize();
        throw exception;
      }
    }
  }

  static uninitialize(){
    CoUninitialize();
  }

  static (IWbemServices, WbemLocator) _connect() {
    // Obtain the initial locator to Windows Management
    // on a particular host computer.
    final wbemLocator = WbemLocator.createInstance();
    final proxy = calloc<IntPtr>();

    // Connect to the root\cimv2 namespace with the
    // current user and obtain pointer pSvc
    // to make IWbemServices calls.

    var hr = wbemLocator.connectServer(
        TEXT('ROOT\\CIMV2'),
        // WMI namespace
        nullptr,
        // User name
        nullptr,
        // User password
        nullptr,
        // Locale
        NULL,
        // Security flags
        nullptr,
        // Authority
        nullptr,
        // Context object
        proxy.cast() // IWbemServices proxy
        );

    if (FAILED(hr)) {
      final exception = COMException(hr);
      wbemLocator.release();
      throw exception;
    }

    final wbemServices = IWbemServices(proxy.cast());

    // Set the IWbemServices proxy so that impersonation
    // of the user (client) occurs.
    hr = CoSetProxyBlanket(
        Pointer.fromAddress(proxy.value),
        // the proxy to set
        RPC_C_AUTHN_WINNT,
        // authentication service
        RPC_C_AUTHZ_NONE,
        // authorization service
        nullptr,
        // Server principal name
        RPC_C_AUTHN_LEVEL.RPC_C_AUTHN_LEVEL_CALL,
        // authentication level
        RPC_C_IMP_LEVEL.RPC_C_IMP_LEVEL_IMPERSONATE,
        // impersonation level
        nullptr,
        // client identity
        EOLE_AUTHENTICATION_CAPABILITIES.EOAC_NONE // proxy capabilities
        );

    if (FAILED(hr)) {
      final exception = COMException(hr);
      wbemServices.release();
      wbemLocator.release();
      throw exception;
    } else {
      return (wbemServices, wbemLocator);
    }
  }

  /// Returns a list of running processes on the current system.
  static List<ProcessInfo> listRunningProcesses({int priority = 8}) {
    final processes = <ProcessInfo>[];
    final connected = _connect();

    final wbemLocator = connected.$2;
    final wbemServices = connected.$1;

    // Use the IWbemServices pointer to make requests of WMI.

    final pEnumerator = calloc<Pointer<COMObject>>();
    IEnumWbemClassObject enumerator;

    // For example, query for all the running processes
    var hr = wbemServices.execQuery(
        TEXT('WQL'),
        TEXT('SELECT * FROM Win32_Process WHERE Priority = $priority'),
        // ExecutablePath IS NOT NULL removed because apex legends
        WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_FORWARD_ONLY |
            WBEM_GENERIC_FLAG_TYPE.WBEM_FLAG_RETURN_IMMEDIATELY,
        nullptr,
        pEnumerator);

    if (FAILED(hr)) {
      final exception = COMException(hr);
      wbemServices.release();
      wbemLocator.release();
      throw exception;
    } else {
      enumerator = IEnumWbemClassObject(pEnumerator.cast());

      final uReturn = calloc<Uint32>();

      while (enumerator.ptr.address > 0) {
        final pClsObj = calloc<Pointer<COMObject>>();

        hr = enumerator.next(
            WBEM_INFINITE, 1, pClsObj, uReturn);

        // Break out of the while loop if we've run out of processes to inspect
        if (uReturn.value == 0) break;

        final clsObj = IWbemClassObject(pClsObj.cast());
        final processName = _getProperty(clsObj, 'Name');
        final processId = int.parse(_getProperty(clsObj, 'Handle'));

        processes.add(ProcessInfo(processName, processId));

        clsObj.release();
      }
    }

    wbemServices.release();
    wbemLocator.release();
    enumerator.release();
    return processes;
  }

  static String _getProperty(IWbemClassObject clsObj, String key) {
    final vtProp = calloc<VARIANT>();
    final keyPtr = key.toNativeUtf16();

    try {
      final hr = clsObj.get(keyPtr, 0, vtProp, nullptr, nullptr);

      if (SUCCEEDED(hr)) {
        return vtProp.ref.bstrVal.toDartString();
      } else {
        return '';
      }
    } finally {
      VariantClear(vtProp);
      free(keyPtr);
    }
  }
}
