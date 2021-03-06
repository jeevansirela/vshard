test_run = require('test_run').new()
REPLICASET_1 = { 'box_1_a', 'box_1_b', 'box_1_c' }
test_run:create_cluster(REPLICASET_1, 'router')
util = require('util')
util.wait_master(test_run, REPLICASET_1, 'box_1_a')
util.map_evals(test_run, {REPLICASET_1}, 'bootstrap_storage(\'memtx\')')
_ = test_run:cmd("create server router_2 with script='router/router_2.lua'")
_ = test_run:cmd("start server router_2")
_ = test_run:switch("router_2")

vshard.router.bootstrap()
--
-- gh-157: introduce vshard.router.callre to prefer slaves to
-- execute a user defined function.
-- gh-168: load-balancing.
--
vshard.router.callre(1, 'echo', {'ok'})
vshard.router.call(1, {mode = 'read', prefer_replica = true}, 'echo', {'ok'})
rs = vshard.router.route(1)
res = rs:callre('echo', {'ok'})
res
_ = test_run:switch('box_1_b')
echo_count
echo_count = 0

-- Basic load-balancing.
_ = test_run:switch('router_2')
for i = 1, 12 do vshard.router.callbro(1, 'echo', {'ok'}) end
for i = 1, 3 do rs:callbro('echo', {'ok'}) end
for i = 1, 3 do vshard.router.call(1, {mode = 'read', balance = true}, 'echo', {'ok'}) end
_ = test_run:switch('box_1_a')
echo_count
echo_count = 0
_ = test_run:switch('box_1_b')
echo_count
echo_count = 0
_ = test_run:switch('box_1_c')
echo_count
echo_count = 0
_ = test_run:switch('router_2')

-- Prefer slaves, but still balance.
for i = 1, 10 do vshard.router.callbre(1, 'echo', {'ok'}) end
for i = 1, 2 do rs:callbre('echo', {'ok'}) end
_ = test_run:switch('box_1_b')
echo_count
echo_count = 0
_ = test_run:switch('box_1_c')
echo_count
echo_count = 0

-- Now turn down some of the nodes - balancers and slave-lovers
-- should not try to visit them.

_ = test_run:switch('router_2')
_ = test_run:cmd('stop server box_1_b')
-- One slave and one master are alive. This call should visit only
-- the slave.
vshard.router.callre(1, 'echo', {'ok'})
_ = test_run:switch('box_1_c')
echo_count
echo_count = 0

_ = test_run:switch('router_2')
-- Just balance over two nodes. It does not matter who is slave,
-- and who is not.
for i = 1, 12 do vshard.router.callbro(1, 'echo', {'ok'}) end
_ = test_run:switch('box_1_a')
echo_count
echo_count = 0
_ = test_run:switch('box_1_c')
echo_count
echo_count = 0

_ = test_run:switch('router_2')
-- Only one slave is alive - not much space to balance.
for i = 1, 10 do vshard.router.callbre(1, 'echo', {'ok'}) end
_ = test_run:switch('box_1_c')
echo_count
echo_count = 0

_ = test_run:switch('router_2')
_ = test_run:cmd('stop server box_1_c')
-- When all the slaves are down, only master can be used. Even if
-- a caller prefers slaves.
vshard.router.callre(1, 'echo', {'ok'})
_ = test_run:switch('box_1_a')
echo_count
echo_count = 0

_ = test_run:switch('router_2')
for i = 1, 3 do vshard.router.callbro(1, 'echo', {'ok'}) end
_ = test_run:switch('box_1_a')
echo_count
echo_count = 0

_ = test_run:switch('router_2')
for i = 1, 3 do vshard.router.callbre(1, 'echo', {'ok'}) end
_ = test_run:switch('box_1_a')
echo_count
echo_count = 0

--
-- What if everything is down? Router should not hang at least.
--
_ = test_run:switch('router_2')
_ = test_run:cmd('stop server box_1_a')
_, err = vshard.router.callre(1, 'echo', {'ok'})
err ~= nil
_, err = vshard.router.callbre(1, 'echo', {'ok'})
err ~= nil
_, err = vshard.router.callbro(1, 'echo', {'ok'})
err ~= nil

_ = test_run:cmd('start server box_1_a')
_ = test_run:cmd('start server box_1_b')
_ = test_run:cmd('start server box_1_c')

_ = test_run:switch("default")
_ = test_run:cmd("stop server router_2")
_ = test_run:cmd("cleanup server router_2")
test_run:drop_cluster(REPLICASET_1)
