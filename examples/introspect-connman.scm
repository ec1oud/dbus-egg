;(use dbus)
(use (prefix dbus dbus:))

(define connman-bus dbus:system-bus) ;; in real life
; (define connman-bus dbus:session-bus) ;; for connman-simulator without root privs

(define ctxt (dbus:make-context
	bus: connman-bus
	service: 'net.connman
))

; (display (dbus:discover-api-xml ctxt))

(define (device-properties device)
  (let ((c (dbus:make-context bus: connman-bus
			      service: 'net.connman
			      interface: 'net.connman.Service
			      path: device)))
    (dbus:call c "GetProperties")))

(define mgr-ctxt (dbus:make-context bus: connman-bus
	service: 'net.connman interface: 'net.connman.Manager))

(printf "~%==== Manager Technologies:~%")
(pretty-print (dbus:call mgr-ctxt "GetTechnologies"))

(printf "~%==== Manager Services:~%")
(pretty-print (dbus:call mgr-ctxt "GetServices"))

;(dbus:auto-unbox-structs #t)
;(dbus:auto-unbox-variants #t)

(printf "~%==== Clock Properties:~%")
(define clock-ctxt (dbus:make-context bus: connman-bus
	service: 'net.connman interface: 'net.connman.Clock))
(pretty-print (dbus:call clock-ctxt "GetProperties"))

(printf "~%==== Manager Properties:~%")
(let ([mgr-props (dbus:call mgr-ctxt "GetProperties")])
	(pretty-print mgr-props)
	(let ([ifaces (assoc "Services" (vector->list (car mgr-props)))])
		(when (pair? ifaces)
			(set! ifaces (vector->list (cdr ifaces)))

(printf "~%==== Network interface Properties:~%")
			(for-each (lambda (path)
					(printf "---- ~a~%" path)
					(pp (device-properties path))
				;	(pp (vector->list (car (device-properties path))))
				) ifaces)
		)))

;(sleep 1)
(exit)
