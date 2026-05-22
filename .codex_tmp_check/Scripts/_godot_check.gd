extends SceneTree
func _init():
    var s = load("res://Scripts/wave_director.gd")
    if s:
        print("OK")
    else:
        print("FAIL")
    quit()
