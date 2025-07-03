import subprocess
import time
import argparse

def run_command(command):
    """Runs a shell command and returns the output."""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip()
    except Exception as e:
        return "", str(e)

def toggle_main_aux(node_ips, node_port):
    """Attempts to toggle the MAIN MAIN flag for all nodes until successful."""
    for node_ip in node_ips:
        command = f"./qubic-cli -seed oetvbpntxzlcgdhafoyjglrfcbegivrbzjlzchfhjudrhcnvsftdqyt -nodeip {node_ip} -nodeport {node_port} -togglemainaux MAIN MAIN"
        while True:
            stdout, stderr = run_command(command)
            print(f"{node_ip}: {stdout}")
            if "Successfully set MAINAUX flag" in stdout:
                break
            print(f"Retrying togglemainaux for {node_ip}...")
            time.sleep(15)  # Increased delay to 10 seconds

def get_epoch(node_ip, node_port):
    """Retrieves the current epoch from the system info."""
    command = f"./qubic-cli -nodeip {node_ip} -nodeport {node_port} -getsysteminfo"
    stdout, stderr = run_command(command)
    print(stdout)
    
    for line in stdout.split('\n'):
        if line.startswith("Epoch: "):
            return line.split(": ")[1].strip()
    return None

def broadcast_computor(node_ip, node_port, epoch):
    """Sends the broadcastComputorTestnet command three times to the last node in the list."""
    command = f"./broadcastComputorTestnet {node_ip} {epoch} {node_port}"
    for _ in range(3):
        stdout, stderr = run_command(command)
        print(stdout)
        time.sleep(1)

def check_tick_info(node_ip, node_port, epoch):
    """Checks the current tick information and repeats broadcasting if needed."""
    check_command = f"./qubic-cli -nodeip {node_ip} -nodeport {node_port} -getcurrenttick"
    
    while True:
        time.sleep(5)  # Wait 5 seconds before checking
        stdout, stderr = run_command(check_command)
        print(stdout)
        
        if "Error while getting tick info" in stdout:
            print("Error detected, rebroadcasting...")
            broadcast_computor(node_ip, node_port, epoch)
        else:
            print("Tick info received successfully.")
            break

def main():
    """Main function to execute the sequence of operations."""
    parser = argparse.ArgumentParser(description="Epoch switcher for Qubic testnet")
    parser.add_argument('--node_ips', type=str, help="Comma-separated list of node IPs.", default="127.0.0.1")
    parser.add_argument('--node_port', type=int, help="Node port number.", default=31841)
    args = parser.parse_args()

    node_ips = args.node_ips.split(',')
    node_port = args.node_port
    
    toggle_main_aux(node_ips, node_port)
    last_node_ip = node_ips[-1]  # Broadcast only to the last node in the list
    
    epoch = get_epoch(last_node_ip, node_port)
    if epoch is None:
        print("Failed to retrieve epoch, exiting.")
        return
    
    broadcast_computor(last_node_ip, node_port, epoch)
    check_tick_info(last_node_ip, node_port, epoch)
    print("Script execution completed.")

if __name__ == "__main__":
    main()
