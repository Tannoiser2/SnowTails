extends SceneTree
func _init() -> void:
	var texts := ["https://tannoiser2.github.io/SnowTails/?r=ABCD", "HELLO", "https://example.com/a/very/long/path/that/needs/version/five/or/six?x=1"]
	for i in texts.size():
		var q := QR.make(texts[i])
		print("v size ", q.size)
		q.image(6).save_png("/tmp/shots/qr_%d.png" % i)
	quit()
