(() => {
  // MV3 disallows inline script execution. FlutterFire's Trusted Types path
  // can attempt inline script injection, which triggers CSP violations.
  try {
    const descriptor = Object.getOwnPropertyDescriptor(window, 'trustedTypes');
    if (descriptor?.configurable) {
      Object.defineProperty(window, 'trustedTypes', {
        value: undefined,
        configurable: true,
        writable: false,
      });
      return;
    }
  } catch (_) {
    // Ignore and fall through to delete attempt.
  }

  try {
    delete window.trustedTypes;
  } catch (_) {
    // If this fails, runtime keeps native Trusted Types.
  }
})();
