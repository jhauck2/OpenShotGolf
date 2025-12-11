import socket

HOST = "127.0.0.1"
PORT =  49152
# Use the relocated test payload
filename = "../../assets/data/drive_test_shot.json"

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((HOST, PORT))

    # Open file to send
    with open(filename, "rb") as f:
        # Read and send file
        bytes_read = f.read(4096) # file should not be larger than this
        if bytes_read:
            print(f"Sending payload from {filename}:\n{bytes_read.decode('utf-8')}")
            s.sendall(bytes_read)

    data = s.recv(1024)

print(f"Received {data!r}")
