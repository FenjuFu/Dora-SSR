local Node = require("Node").Type
local Sprite = require("Sprite").Type
local record VGNode
	embed Node
	const surface: Sprite
	render: function(self: VGNode, func: function())
end
local record VGNodeClass
	type Type = VGNode
	metamethod __call: function(
		self: VGNodeClass,
		width: number,
		height: number,
		scale?: number --[[1.0]],
		edgeAA?: integer --[[1]]
	): VGNode
end
local vgNodeClass: VGNodeClass
return vgNodeClass
