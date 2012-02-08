(use dbus)

(define ctxt (dbus:make-context
	bus: dbus:system-bus
	service: 'net.connman
	;path: '/net/connman
))

(let ([response (dbus:discover-api-xml ctxt)])
	(display response)
)

(define mgr-ctxt (dbus:make-context bus: dbus:system-bus
	service: 'net.connman interface: 'net.connman.Manager))

(printf "~%==== Manager Properties:~%")
(pretty-print (dbus:call mgr-ctxt "GetProperties"))

(printf "~%==== Manager Services:~%")
(pretty-print (dbus:call mgr-ctxt "GetServices"))

(define clock-ctxt (dbus:make-context bus: dbus:system-bus
	service: 'net.connman interface: 'net.connman.Clock))

(printf "~%==== Clock Properties:~%")
(pretty-print (dbus:call clock-ctxt "GetProperties"))

(sleep 1)
(exit)
