# Throttle

This is a demonstration Rails application to illustrate a controller concern
to throttle requests. The concern can be included in a controller to
selectively protect actions.

The throttle uses cookie and user-agent/ip-addr fingerprinting. Firstly, a
`_id` cookie is set to identify subsequent requests. A secondary, passive
fingerprint is also used to identify cookie-disabled user agents. The
remote host's user-agent and ip address http headers are used for this passive
fingerprinting as recommended by W3C at https://www.w3.org/TR/fingerprinting-guidance/

The throttle itself is simply a queue as an array class instance variable.
A mutex surrounds the queue to allow thread-safe access. The queue holds the
most recent one-hundred requests indexed by requests' fingerprints. Upon the
101st request, a check is made against the time of the oldest request in the
queue for that fingerprint.

Since the throttle does not know if the user agent is cookie-enabled, the queue
is indexed by both cookie and passive fingerprints.

The queue is thread-safe; consequently, it is able to protect a controller's
endpoint in multi-threaded installations, such as Puma in a `thread`
configuration. However, the queue is not in shared memory across processes;
consequently it would not afford throttle protection with Puma's `worker`
configuration or (for example) a Heroku deployment with multiple dynos.

Furthermore, this implementation doesn't protect from malicious botnets; if
each of the individual attackers in such a scenario keep their requests below
the throttle threshold, it would be possible to flood the controller from
multiple remote hosts without the throttle detecting an attack. To overcome
such a scenario, the system would be need to recognise that simultaneous
'similar' requests are being received from different hosts over the same
period of time.

Specs are included for the controller concern. Unfortunately, RSpec is not
thread-safe; consequently the simultaneous test is marked as pending.
