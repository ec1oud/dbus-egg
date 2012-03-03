(use (prefix dbus dbus:))

(define (device-properties device)
  (let ((c (dbus:make-context
				;bus: dbus:system-bus
				service: 'net.connman
				interface: 'net.connman.Service
				path: device)))
    (dbus:call c "GetProperties")))

(pp (device-properties '/net/connman/service/ethernet_c80aa9daaea5_cable))
