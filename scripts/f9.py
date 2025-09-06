#!/usr/bin/env python3

import subprocess
import time
import argparse
import logging

# Configure logging
logging.basicConfig(filename='qubic-cli.log', level=logging.INFO, format='%(asctime)s - %(message)s')

# Hardcoded seed
SEED = "oetvbpntxzlcgdhafoyjglrfcbegivrbzjlzchfhjudrhcnvsftdqyt"

def execute_command2(ip_list, port):
    for ip in ip_list:
        command = f"./qubic-cli -nodeip {ip} -nodeport {port} -seed {SEED} -refreshpeerlist"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        logging.info(f"Output from {ip}:\n{result.stdout}")
        if result.stderr:
            logging.error(f"Error from {ip}:\n{result.stderr}")

def execute_command(ip_list, port):
    for ip in ip_list:
        command = f"./qubic-cli -nodeip {ip} -nodeport {port} -seed {SEED} -reissuevote"
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        print(f"{result.stdout}")
        logging.info(f"Output from {ip}:\n{result.stdout}")
        if result.stderr:
            logging.error(f"Error from {ip}:\n{result.stderr}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run qubic-cli with specified IPs and port.")
    parser.add_argument('--node_ips', type=str, required=True, help="List of IP addresses, separated by commas.")
    parser.add_argument('--node_port', type=int, required=True, help="Port for connecting to nodes.")

    args = parser.parse_args()
    time.sleep(600) # Wait for 10 minutes 
    node_ips = args.node_ips.split(",")
    node_port = args.node_port

    while True:
     #   execute_command2(node_ips, node_port)
        execute_command(node_ips, node_port)
        time.sleep(5)  
