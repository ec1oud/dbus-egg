(use (prefix dbus dbus:))

(define ctxt (dbus:make-context
	bus: dbus:system-bus
	service: 'org.freedesktop.Hal
	path: '/org/freedesktop/Hal/Manager
))

(let ([response (dbus:discover-api-xml ctxt)])
	(display response)
)

(exit)
