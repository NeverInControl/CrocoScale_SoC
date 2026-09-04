import os
import sys

def extract_header_footer(base_name):
    input_file = f"{base_name}.bin"

    if not os.path.exists(input_file):
        print(f"Error: Could not find file '{input_file}'")
        return

    with open(input_file, 'rb') as f:
        bitstream = f.read()
    
    sync_marker = bytes.fromhex("FAB0FAB1")
    footer_marker = bytes.fromhex("00100000")

    sync_idx = bitstream.find(sync_marker)
    if sync_idx == -1:
        print("Error: Sync word 'FAB0FAB1' not found in the bitstream.")
        return

    footer_idx = bitstream.rfind(footer_marker)
    if footer_idx == -1:
        print("Error: Footer '00100000' not found in the bitstream.")
        return

    header_end_idx = sync_idx + len(sync_marker)
    header = bitstream[:header_end_idx]
    
    print(f"Found 'FAB0FAB1' starting at byte index: {sync_idx}")
    print(f"Extracted Header (including marker): {len(header)} bytes")

    with open(f"header.bin", "wb") as f:
        f.write(header)

    footer = bitstream[footer_idx : footer_idx + len(footer_marker)]
    print(f"Found '00100000' starting at byte index: {footer_idx}")
    print(f"Extracted Footer: {len(footer)} bytes")

    with open(f"footer.bin", "wb") as f:
        f.write(footer)

    payload = bitstream[header_end_idx:footer_idx]
    
    # Overwrite the original input file with the payload
    with open(input_file, "wb") as f:
        f.write(payload)
        
    print(f"\nSuccess! Sliced the bitstream into:")
    print(f" - header.bin  (Ends with FAB0FAB1)")
    print(f" - {input_file} (Original file overwritten with the payload)")
    print(f" - footer.bin  (Exactly 00100000)")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <filename_without_extension>")
        sys.exit(1)
        
    base_filename = sys.argv[1]
    extract_header_footer(base_filename)