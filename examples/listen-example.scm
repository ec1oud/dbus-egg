(use (prefix dbus dbus:))

(define (query . params)
	(printf "got a query; params: ~s~%" params)
	;; the response to the query:
	`(#t 42))

(define ctxt (dbus:make-context
	service: 'test.method.server
	interface: 'test.method.Type
	path: '/test/method/Object))

(dbus:register-method ctxt "Method" query)
