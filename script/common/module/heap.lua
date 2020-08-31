local lheap = require "lheap"

function create(is_max_prior)
	return Heap:new({
		is_max_prior = is_max_prior,
	})
end

local MAX_HEAP_NODE_ID = math.pow(2, 10)

Heap = Object:inherit()
function Heap:on_init(OCI)
	self.is_max_prior = OCI and OCI.is_max_prior
	self:clean()
end

function Heap:clean()
	self.nextid = 0
	self.id2val = {}
	self.heap = lheap.new(1024, self.is_max_prior and 1)
end

function Heap:get_len()
	return self.heap:len()
end

function Heap:empty()
	return self.heap:len() == 0
end

function Heap:push(value, data, id)
	assert(value)
	data = data or true
	local id2val = self.id2val
	if not id then
		id = self.nextid

		while id2val[id]
		do
			id = (id + 1) % MAX_HEAP_NODE_ID
		end
		self.nextid = (id + 1) % MAX_HEAP_NODE_ID
	else
		assert(not id2val[id])
	end

	self.heap:push(id, value)
	id2val[id] = data

	return id
end

function Heap:top()
	local id2val = self.id2val
	local topid, topv = self.heap:top()
	assert(id2val[topid])
	return topv, id2val[topid], topid
end

function Heap:pop()
	local id2val = self.id2val
	local topid = self.heap:top()
	assert(id2val[topid])
	id2val[topid] = nil
	self.heap:pop()
end

function Heap:pop_by_id(id)
	local id2val = self.id2val
	if not id2val[id] then return end
	id2val[id] = nil

	return self.heap:popbykey(id)
end

function Heap:get_data(id)
	return self.id2val[id]
end
