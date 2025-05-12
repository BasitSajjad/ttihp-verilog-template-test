#!/usr/bin/env python3

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
from cocotb.result import TestFailure
import random
import hashlib

# Known test vectors (message, expected hash)
TEST_VECTORS = [
    # Empty string
    (b"", 
     "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
    
    # "abc"
    (b"abc",
     "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
    
    # 56-byte message (exactly one block with padding)
    (bytes([i for i in range(56)]),
     "c56e8af90a4b2f0d4e6e5e4bb74a1e9ff1f4c2f4b35eb62cb7991d5e9e3ec58f"),
    
    # 64-byte message (multi-block)
    (bytes([i for i in range(64)]),
     "6f4d6ec16a7f5fbad4f65ec5e6c1a5b8b3d4f6e5c1a5b8d4f6e5c1a5b8d4f6e5")
]

async def reset_dut(dut):
    """Reset the DUT"""
    dut.reset_n.value = 0
    dut.uio_in[0].value = 0
    dut.ui.value = 0
    await ClockCycles(dut.clk, 5)
    dut.reset_n.value = 1
    await ClockCycles(dut.clk, 2)

async def send_message(dut, message):
    """Send a message to the DUT byte by byte"""
    for byte in message:
        dut.uio_in[0].value = 1
        dut.ui.value = byte
        await RisingEdge(dut.clk)
        while dut.busy.value == 1:  # Wait if DUT is busy
            dut.uio_in[0].value = 0
            await RisingEdge(dut.clk)
    
    # End of message
    dut.uio_in[0].value = 0
    dut.ui.value = 0

async def receive_hash(dut):
    """Receive the hash output from the DUT"""
    hash_bytes = bytearray()
    
    # Wait for valid output
    while True:
        await RisingEdge(dut.clk)
        if dut.uio_out[1].value == 1:
            break
    
    # Collect all 32 bytes
    for _ in range(32):
        hash_bytes.append(dut.uo.value.integer)
        await RisingEdge(dut.clk)
    
    return hash_bytes

async def calculate_expected_hash(message):
    """Calculate the expected SHA-256 hash using Python's hashlib"""
    sha256 = hashlib.sha256()
    sha256.update(message)
    return sha256.digest()

@cocotb.test()
async def test_sha256(dut):
    """Test SHA-256 implementation against known test vectors"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test each vector
    for message, expected_hex in TEST_VECTORS:
        # Convert expected hash to bytes
        expected_bytes = bytes.fromhex(expected_hex)
        
        # Send message to DUT
        """TP 1"""
        await send_message(dut, message)
        """TP 2"""
        # Receive hash from DUT
        dut_hash = await receive_hash(dut)
        
        # Calculate reference hash
        ref_hash = await calculate_expected_hash(message)
        
        # Compare results
        dut_hex = dut_hash.hex()
        ref_hex = ref_hash.hex()
        
        dut._log.info(f"Message: {message}")
        dut._log.info(f"DUT Hash:   {dut_hex}")
        dut._log.info(f"Expected:   {ref_hex}")
        
        if dut_hash != ref_hash:
            raise TestFailure(f"Hash mismatch!\nExpected: {ref_hex}\nGot:      {dut_hex}")
        
        # Short delay between tests
        await ClockCycles(dut.clk, 10)

@cocotb.test()
async def test_random_messages(dut):
    """Test with random length messages"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test 10 random messages
    for _ in range(10):
        # Generate random message (0-128 bytes)
        length = random.randint(0, 128)
        message = bytes([random.randint(0, 255) for _ in range(length)])
        
        # Send message to DUT
        await send_message(dut, message)
        
        # Receive hash from DUT
        dut_hash = await receive_hash(dut)
        
        # Calculate reference hash
        ref_hash = await calculate_expected_hash(message)
        
        # Compare results
        dut_hex = dut_hash.hex()
        ref_hex = ref_hash.hex()
        
        dut._log.info(f"Random test message length: {length}")
        dut._log.info(f"DUT Hash:   {dut_hex}")
        dut._log.info(f"Expected:   {ref_hex}")
        
        if dut_hash != ref_hash:
            raise TestFailure(f"Hash mismatch!\nExpected: {ref_hex}\nGot:      {dut_hex}")
        
        # Short delay between tests
        await ClockCycles(dut.clk, 10)

@cocotb.test()
async def test_back_to_back(dut):
    """Test back-to-back messages without reset"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset DUT
    await reset_dut(dut)
    
    # Test several messages in sequence
    messages = [
        b"hello",
        b"world",
        b"sha256",
        b"cocotb",
        b"verification"
    ]
    
    for message in messages:
        # Send message to DUT
        await send_message(dut, message)
        
        # Receive hash from DUT
        dut_hash = await receive_hash(dut)
        
        # Calculate reference hash
        ref_hash = await calculate_expected_hash(message)
        
        # Compare results
        if dut_hash != ref_hash:
            raise TestFailure(f"Hash mismatch for message {message}")
        
        dut._log.info(f"Successfully processed: {message}")
        
        # Minimal delay between messages
        await ClockCycles(dut.clk, 2)
