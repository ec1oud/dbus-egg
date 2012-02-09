(use (prefix dbus dbus:))

(define rc-car-context (dbus:make-context
	bus: dbus:session-bus 	;; would be the session-bus by default anyway
	service: 'com.trolltech.CarExample
	interface: 'com.trolltech.Examples.CarInterface
	path: '/Car))

(dbus:call rc-car-context "turnRight")
(exit)
