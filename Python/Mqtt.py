import paho.mqtt.client as mqtt
import keyboard
import sys
import os
from dotenv import load_dotenv

load_dotenv()

#Var Init
red = 0
orange = 0
green = 0
blue = 0
white = 0
buzzerc = 0
buzzerp = 0

#Init MQTT
BROKER = os.getenv("BROKER")
PORT = os.getenv("PORT")

client = mqtt.Client()
client.connect(BROKER, PORT, keepalive=60)


#Defining Colors 
def Red():
    global red
    if red == 0:
        red = 1
    elif red == 1:
        red = 2
    elif red == 2:
        red = 0
    print(f"r={red}")

def Orange():
    global orange
    if orange == 0:
        orange = 1
    elif orange == 1:
        orange = 2
    elif orange == 2:
        orange = 0
    print(f"o={orange}")

def Green():
    global green
    if green == 0:
        green = 1
    elif green == 1:
        green = 2
    elif green == 2:
        green = 0
    print(f"g={green}")

def Blue():
    global blue
    if blue == 0:
        blue = 1
    elif blue == 1:
        blue = 2
    elif blue == 2:
        blue = 0
    print(f"b={blue}")

def White():
    global white
    if white == 0:
        white = 1
    elif white == 1:
        white = 2
    elif white == 2:
        white = 0
    print(f"w={white}")

def Buzzerc():
        global buzzerc
        if buzzerc == 0:
            buzzerc = 1
        elif buzzerc == 1:
            buzzerc = 0
        print(f"bc={buzzerc}")

def Buzzerp():
        global buzzerp
        if buzzerp == 0:
            buzzerp = 1
        elif buzzerp == 1:
            buzzerp = 0
        print(f"bp={buzzerp}")

def Exit():
    client.disconnect()
    print("MQTT-Verbindung beendet")
    print("Script wird beendet")
    exit()
    
#Selected Shortcuts calling Function
keyboard.add_hotkey("ctrl+alt+1", Red)
keyboard.add_hotkey("ctrl+alt+2", Orange)
keyboard.add_hotkey("ctrl+alt+3", Green)
keyboard.add_hotkey("ctrl+alt+4", Blue)
keyboard.add_hotkey("ctrl+alt+5", White)
keyboard.add_hotkey("ctrl+alt+6", Buzzerc)
keyboard.add_hotkey("ctrl+alt+7", Buzzerp)
keyboard.add_hotkey("ctrl+alt+0", Exit)

client.publish("stange/rot", payload="{red}", qos=1)
client.publish("stange/orange", payload="{orange}", qos=1)
client.publish("stange/grün", payload="{green}", qos=1)
client.publish("stange/grün", payload="{blue}", qos=1)
client.publish("stange/grün", payload="{white}", qos=1)
client.publish("stange/grün", payload="{buzzerc}", qos=1)
client.publish("stange/grün", payload="{buzzerp}", qos=1)

keyboard.wait()