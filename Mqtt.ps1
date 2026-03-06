import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
TOPIC = "demo/int"

value = 23  # Integer

client = mqtt.Client()
client.connect(BROKER, PORT, keepalive=60)

# qos: 0/1/2, retain: True/False
client.publish(TOPIC, payload=str(value), qos=1, retain=False)

client.disconnect()