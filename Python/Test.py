import keyboard

#Var Init
red = 0

#Defining Colors 
def Red():
    global red
    if red == 0:
        red = 1
    elif red == 1:
        red = 2
    elif red == 2:
        red = 0
    print(red)


#Selected Shortcuts calling Function
keyboard.add_hotkey("ctrl+alt+1", Red)

keyboard.wait()
