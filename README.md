## SSL Chain Extractor

### Overview
**SSL Chain Extractor** is a simple Python-based utility with a graphical user interface (GUI) that extracts the full certificate chain (leaf, intermediate, and root certificates) from a given SSL certificate. It provides the option to break out each certificate into separate files and generate a `FullChain.cer` file for easy integration in applications requiring a complete certificate chain.

The program supports PEM, CRT, and CER formats and includes functionality to fetch missing intermediate or root certificates using the Authority Information Access (AIA) extension or the trusted root certificates available in the system or via `certifi`.

### How to Use:
1. **Select an SSL Certificate**: Use the GUI to select a `.pem`, `.crt`, or `.cer` file.
2. **Extract Certificates**: Click the "Extract Certificates" button to extract the leaf, intermediate, and root certificates.
3. **Create FullChain**: Optionally, click "Create FullChain.cer" to generate a single file containing the entire certificate chain.
4. **Save Output**: Each certificate is saved to a separate file (e.g., `cert_leaf.cer`, `cert_intermediate_1.cer`, `cert_root.cer`).

### Key Features:
- **Extract Certificates**: Extracts the leaf, intermediate, and root certificates from a provided SSL certificate file.
- **Save Certificates**: Saves each certificate as a separate file (leaf, intermediate(s), and root).
- **Create FullChain.cer**: Combines the entire certificate chain into a `FullChain.cer` file for easy use.
- **Fetch Intermediate/Root Certificates**: Automatically fetches missing intermediate and root certificates from the web using AIA or from trusted root stores (`certifi`).
- **Simple GUI**: Intuitive user interface built with Tkinter for easy file selection and execution.

<!-- GitAds-Verify: U2PZCAGVH2BXULX6VEWZYE8ZHUEBDCHV -->
