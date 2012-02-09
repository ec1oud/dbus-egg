(use (prefix dbus dbus:))

(define ctxt (dbus:make-context
	service: 'test.method.server
	interface: 'test.method.Type
	path: '/test/method/Object))

(define remote-method (dbus:make-method-proxy ctxt "Method"))

(let ([response (remote-method "query"
		"What is the meaning of life, the universe and everything?") ])

	(printf "sent a very important query with a known answer; got flippant response ~s~%" response)
	(if (and (list? response) (eq? 42 (cadr response)))
		(printf "bingo!~%")
		(printf "and the answer is wrong too!  Bad supercomputer, bad!~%")))

(exit)
