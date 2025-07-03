#!/usr/bin/env python3

import argparse
import random
import subprocess
import time
from datetime import datetime

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def get_system_info(ip, port):
    try:
        result = subprocess.run(["./qubic-cli", "-nodeip", ip, "-nodeport", str(port), "-getsysteminfo"], capture_output=True, text=True, timeout=10)
        log(f"Response from {ip}:{port}: {result.stdout.strip()}")
        return result.stdout.strip()
    except Exception as e:
        log(f"Error executing command on {ip}: {e}")
        return ""

def send_special_command(ip, port):
    log(f"Sending special command to {ip}:{port}")
    subprocess.run(["./qubic-cli", "-seed", "oetvbpntxzlcgdhafoyjglrfcbegivrbzjlzchfhjudrhcnvsftdqyt", "-nodeip", ip, "-nodeport", str(port), "-sendspecialcommand", "16"])

def broadcast_computor(ip, epoch, port):
    log(f"Broadcasting computor list to {ip} for epoch {epoch}")
    subprocess.run(["./broadcastComputorTestnet", ip, str(epoch), str(port)])

def main():
    parser = argparse.ArgumentParser(description="Epoch switcher for Qubic testnet")
    parser.add_argument('--node_ips', type=str, help="Comma-separated list of node IPs.", default="127.0.0.1")
    parser.add_argument('--node_port', type=int, help="Node port number.", default=31841)
    args = parser.parse_args()

    node_ips = args.node_ips.split(',')
    node_port = args.node_port
    last_epoch, initial_tick = None, None
    last_tick = None

    while True:
        random.shuffle(node_ips)
        for ip in node_ips:
            log(f"Checking system info on {ip}:{node_port}")
            response = get_system_info(ip, node_port)
            
            if not response or "Failed to connect" in response or "Unable to establish connection" in response:
                log(f"Connection to {ip} failed, trying next IP...")
                continue
            
            try:
                epoch = int(response.split("Epoch: ")[1].split("\n")[0])
                tick = int(response.split("Tick: ")[1].split("\n")[0])
                initial_tick = int(response.split("InitialTick: ")[1].split("\n")[0])
            except (IndexError, ValueError):
                log(f"Failed to parse system info from {ip}")
                continue
            
            log(f"Current epoch: {epoch}, Tick: {tick}, Initial Tick: {initial_tick}")
            
            if last_epoch is None:
                last_epoch = epoch
                last_tick = tick
                log(f"Initial epoch set to {last_epoch}, initial tick set to {initial_tick}")
                continue
            
            if epoch > last_epoch:
                log(f"Epoch changed from {last_epoch} to {epoch}")
                all_new_epoch = all(get_system_info(ip, node_port).split("Epoch: ")[1].split("\n")[0] == str(epoch) and get_system_info(ip, node_port).split("Tick: ")[1].split("\n")[0] == str(initial_tick) for ip in node_ips)
                
                if all_new_epoch:
                    log("All nodes have switched to new epoch, broadcasting computor list...")
                    broadcast_computor(node_ips[-1], epoch, node_port)
                    time.sleep(10)
                    
                    response = get_system_info(node_ips[-1], node_port)
                    new_tick = int(response.split("Tick: ")[1].split("\n")[0]) if "Tick: " in response else 0
                    if new_tick == initial_tick:
                        log("Network did not start, retransmitting computor list...")
                        broadcast_computor(node_ips[-1], epoch, node_port)
                    
                    last_epoch = epoch
                    continue
            
            if tick == last_tick and ((tick - initial_tick - 1) % 100 == 0) and tick != initial_tick:
                log(f"Node {ip} is stuck, sending special command...")
                send_special_command(ip, node_port)
                time.sleep(40)
                continue
        
        last_tick = tick
        log("Waiting 30 seconds before next check...")
        time.sleep(30)

if __name__ == "__main__":
    main()
