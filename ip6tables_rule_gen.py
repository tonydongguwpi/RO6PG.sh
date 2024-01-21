import sys
import ipaddress
import random

def generate_ipv6_with_random_host_bits(subnet, count):
    ipv6_addresses = []

    # Split the subnet into network and host parts
    network = ipaddress.IPv6Network(subnet, strict=False)
    
    for _ in range(count):
        # Generate random bits for host part
        random_host_bits = ''.join(random.choice('01') for _ in range(network.max_prefixlen - network.prefixlen))

        # Combine the network and random host bits to form a new IPv6 address
        new_ipv6 = ipaddress.IPv6Address(int(network.network_address) + int(random_host_bits, 2))
        ipv6_addresses.append(new_ipv6)

    return ipv6_addresses

def calculate_probability(index, count):
    # Calculate the probability for each address to be assigned
    return (index + 1) / count

def main():
    # Check if correct number of arguments is provided
    if len(sys.argv) != 3:
        print("Usage: python script.py <IPv6_subnet e.g. 2605:6400:8180::/48> <address_count>")
        sys.exit(1)

    # Get IPv6 subnet and address count from command line arguments
    subnet = sys.argv[1]
    count = int(sys.argv[2])

    # Generate IPv6 addresses with random host bits
    ipv6_addresses = generate_ipv6_with_random_host_bits(subnet, count)

    # Output iptables commands with increasing probability
    for i, ipv6_address in enumerate(ipv6_addresses):
        probability = calculate_probability(i, count)
        print(f"ip6tables -t nat -A POSTROUTING -m statistic --mode random --probability {probability:.8f} -j SNAT --to-source {ipv6_address}")

if __name__ == "__main__":
    main()
