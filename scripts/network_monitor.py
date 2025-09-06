#!/usr/bin/env python3

import argparse
import subprocess
import time
import os
import signal
from datetime import datetime

def log(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")

def get_system_info(ip, port):
    """Get system information via qubic-cli"""
    try:
        result = subprocess.run(["./qubic-cli", "-nodeip", ip, "-nodeport", str(port), "-getsysteminfo"], 
                              capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "Timeout"
    except Exception as e:
        log(f"Error executing command on {ip}: {e}")
        return "Error"

def extract_tick(response):
    """Extract Tick value from response"""
    try:
        if "Tick: " in response:
            tick_line = [line for line in response.split('\n') if line.startswith('Tick: ')][0]
            return int(tick_line.split('Tick: ')[1])
        return None
    except (IndexError, ValueError):
        return None

def is_connection_error(response):
    """Check if response is a connection error"""
    error_patterns = [
        "Error while getting system info from",
        "Failed to connect",
        "Unable to establish connection",
        "No connection",
        "Timeout",
        "Error"
    ]
    return any(pattern in response for pattern in error_patterns)

def send_reissue_vote(ip, port):
    """Send reissuevote command"""
    try:
        result = subprocess.run(["./qubic-cli", "-nodeip", ip, "-nodeport", str(port), "-seed", "oetvbpntxzlcgdhafoyjglrfcbegivrbzjlzchfhjudrhcnvsftdqyt", "-reissuevote"], capture_output=True, text=True, timeout=10)
        log(f"Reissue vote sent to {ip}:{port}")
        return result.stdout.strip()
    except Exception as e:
        log(f"Error sending reissue vote to {ip}: {e}")
        return ""

def main():
    parser = argparse.ArgumentParser(description="Network monitor for Qubic testnet")
    parser.add_argument('--node_ips', type=str, help="Comma-separated list of node IPs.", default="127.0.0.1")
    parser.add_argument('--node_port', type=int, help="Node port number.", default=31841)
    args = parser.parse_args()

    node_ips = args.node_ips.split(',')
    node_port = args.node_port
    
    log(f"Starting network monitor for nodes: {node_ips}, port: {node_port}")
    
    # Variables for state tracking
    last_tick = None
    stuck_count = 0
    connection_error_count = 0
    last_connection_error_time = None
    
    while True:
        current_time = time.time()
        all_nodes_responding = True
        current_tick = None
        
        # Check each node
        for ip in node_ips:
            log(f"Checking system info on {ip}:{node_port}")
            response = get_system_info(ip, node_port)
            
            if is_connection_error(response):
                all_nodes_responding = False
                log(f"Connection error to {ip}:{node_port}")
                if last_connection_error_time is None:
                    last_connection_error_time = current_time
                    connection_error_count = 1
                else:
                    connection_error_count += 1
                continue
            else:
                # If at least one node responds, reset error counter
                if last_connection_error_time is not None:
                    log(f"Connection restored to {ip}:{node_port}")
                    last_connection_error_time = None
                    connection_error_count = 0
            
            # Extract tick from response
            tick = extract_tick(response)
            if tick is not None:
                if current_tick is None:
                    current_tick = tick
                elif tick != current_tick:
                    log(f"Warning: Different ticks detected. Node {ip} has tick {tick}, others have {current_tick}")
        
        # Check if tick is stuck
        if current_tick is not None:
            if last_tick is not None and current_tick == last_tick:
                stuck_count += 1
                log(f"Tick stuck at {current_tick} for {stuck_count} checks")
                
                # If tick is stuck for 1 check (5 minutes), send reissuevote
                if stuck_count >= 1:
                    log("Tick stuck for 5 minutes, sending reissue vote...")
                    for ip in node_ips:
                        send_reissue_vote(ip, node_port)
                    stuck_count = 0
            else:
                stuck_count = 0
                log(f"Tick updated: {current_tick}")
            
            last_tick = current_tick
        
        # Check connection errors
        if not all_nodes_responding and connection_error_count >= 5:
            # If connection errors continue for 20 minutes (4 checks of 5 minutes each)
            if last_connection_error_time and (current_time - last_connection_error_time) >= 1200:  # 20 minutes
                log("Network unresponsive for 20 minutes, initiating restart...")
                
                # Start restart script
                subprocess.Popen(['/root/qubic/qubic_docker/restart_network.sh'], 
                               stdout=subprocess.DEVNULL, 
                               stderr=subprocess.DEVNULL)
                
                log("Restart script launched, exiting monitor")
                return
        
        log("Waiting 5 minutes before next check...")
        time.sleep(300)  # 5 минут

if __name__ == "__main__":
    main()
