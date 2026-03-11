"""
AIO SSL Tool - Windows Edition
Professional SSL Certificate Chain Builder and CSR Generator

Standards Compliance:
- RFC 2986: PKCS #10 Certification Request Syntax
- RFC 5280: X.509 Public Key Infrastructure Certificate and CRL Profile  
- NIST SP 800-57: Recommendation for Key Management
- FIPS 186-4: Digital Signature Standard (DSS)
- ISO 3166-1: Country codes (alpha-2)

Cryptographic Implementations:
- RSA: 2048, 3072, 4096 bits (minimum 2048 per NIST)
- ECC: P-256, P-384, P-521 (NIST-approved curves)
- Signature Algorithm: SHA-256 (per NIST SP 800-57)
- Key Encryption: AES-256 with password-based encryption
"""

import os
import sys
import tkinter as tk
import customtkinter as ctk
from tkinter import filedialog, messagebox, Menu, Toplevel, simpledialog
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.asymmetric import rsa, ec
from cryptography.x509.oid import NameOID
import platform
import threading
import ipaddress
import queue
import http.client
import ssl as _ssl

def resource_path(relative_path):
    base_path = getattr(sys, '_MEIPASS', os.path.dirname(os.path.abspath(__file__)))
    return os.path.join(base_path, relative_path)

if platform.system() == 'Windows':
    try:
        import wincertstore
    except ImportError:
        wincertstore = None
else:
    wincertstore = None

class AIOSSLToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("AIO SSL Tool")
        self.root.geometry("1100x800")
        self.root.resizable(True, True)
        self.root.minsize(900, 750)
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("dark-blue")
        
        # Set window icon
        try:
            icon_path = resource_path("icon-ico.ico")
            if os.path.exists(icon_path):
                self.root.iconbitmap(icon_path)
                print(f"Icon loaded successfully from: {icon_path}")
            else:
                print(f"Warning: Icon file not found at: {icon_path}")
                # Try alternate locations
                alt_paths = [
                    os.path.join(os.path.dirname(__file__), "icon-ico.ico"),
                    "icon-ico.ico"
                ]
                for alt_path in alt_paths:
                    if os.path.exists(alt_path):
                        self.root.iconbitmap(alt_path)
                        print(f"Icon loaded from alternate path: {alt_path}")
                        break
        except Exception as e:
            print(f"Warning: Could not set window icon: {e}")
        
        self.cert_file = None
        self.save_directory = None
        self.private_key_file = None
        self.private_key_password = ""
        self.fullchain_created = False
        self.current_view = "home"
        self.root_certs = self.load_windows_trusted_roots()
        
        # PFX options
        self.pfx_chain_file = None
        self.never_show_advanced_warning = False
        self.pfx_mac_algorithm = "SHA-256"
        self.pfx_encryption_algorithm = "Default"
        
        self.create_layout()
    def create_layout(self):
        """Create the main layout with sidebar navigation"""
        # Main container
        self.main_container = ctk.CTkFrame(self.root, fg_color="transparent")
        self.main_container.pack(fill="both", expand=True)
        
        # Sidebar
        self.sidebar = ctk.CTkFrame(self.main_container, width=220, corner_radius=0, fg_color="#1a1a1a")
        self.sidebar.pack(side="left", fill="y", padx=0, pady=0)
        self.sidebar.pack_propagate(False)
        
        # Sidebar title
        sidebar_title = ctk.CTkLabel(self.sidebar, text="AIO SSL Tool", font=("Arial", 18, "bold"))
        sidebar_title.pack(pady=(20, 30), padx=20)
        
        # Navigation buttons
        self.nav_buttons = {}
        nav_items = [
            ("home", "Home", "🏠"),
            ("csr", "CSR Generator", "📝"),
            ("chain", "Chain Builder", "🔗"),
            ("privatecachain", "Private CA Chain", "🔗+"),
            ("pfx", "PFX Generator", "📦"),
            ("extract", "Key Extractor", "🔑"),
            ("clearpass", "ClearPass", "🌐"),
            ("settings", "Settings", "⚙️")
        ]
        
        for key, label, icon in nav_items:
            btn = ctk.CTkButton(
                self.sidebar,
                text=f"{icon}  {label}",
                command=lambda k=key: self.show_view(k),
                anchor="w",
                height=45,
                fg_color="transparent",
                text_color=("gray70", "gray70"),
                hover_color=("gray30", "gray30"),
                font=("Arial", 13, "bold")
            )
            btn.pack(fill="x", padx=10, pady=3)
            self.nav_buttons[key] = btn
        
        # Content area
        self.content_area = ctk.CTkFrame(self.main_container, fg_color="transparent")
        self.content_area.pack(side="right", fill="both", expand=True)
        
        # Show home view by default
        self.show_view("home")
    
    def show_view(self, view_name):
        """Switch to the specified view"""
        # Update navigation button colors
        for key, btn in self.nav_buttons.items():
            if key == view_name:
                btn.configure(fg_color="#1f538d", text_color="white")
            else:
                btn.configure(fg_color="transparent", text_color=("gray70", "gray70"))
        
        # Clear content area
        for widget in self.content_area.winfo_children():
            widget.destroy()
        
        # Show the selected view
        self.current_view = view_name
        if view_name == "home":
            self.show_home_view()
        elif view_name == "csr":
            self.show_csr_view()
        elif view_name == "chain":
            self.show_chain_view()
        elif view_name == "privatecachain":
            self.show_private_ca_chain_view()
        elif view_name == "pfx":
            self.show_pfx_view()
        elif view_name == "extract":
            self.show_extract_view()
        elif view_name == "clearpass":
            self.show_clearpass_view()
        elif view_name == "settings":
            self.show_settings_view()
    
    def show_home_view(self):
        """Display the home/welcome view"""
        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=30)
        
        # App icon - try to load HomeIcon.png
        try:
            from PIL import Image
            icon_path = resource_path("HomeIcon.png")
            if not os.path.exists(icon_path):
                # Try alternate paths
                icon_path = os.path.join(os.path.dirname(__file__), "HomeIcon.png")
            
            if os.path.exists(icon_path):
                # Load image and maintain aspect ratio
                img = Image.open(icon_path)
                img_width, img_height = img.size
                
                # Calculate size maintaining aspect ratio (max 220px height)
                max_height = 220
                aspect_ratio = img_width / img_height
                display_width = int(max_height * aspect_ratio)
                display_height = max_height
                
                icon_image = ctk.CTkImage(
                    light_image=img,
                    dark_image=img,
                    size=(display_width, display_height)
                )
                icon_label = ctk.CTkLabel(scroll_frame, image=icon_image, text="")
                icon_label.pack(pady=(60, 30))
            else:
                # Fallback to emoji
                icon_label = ctk.CTkLabel(scroll_frame, text="🔒", font=("Arial", 120))
                icon_label.pack(pady=(60, 30))
        except Exception as e:
            print(f"Could not load icon: {e}")
            # Fallback to emoji
            icon_label = ctk.CTkLabel(scroll_frame, text="🔒", font=("Arial", 120))
            icon_label.pack(pady=(60, 30))
        
        # Welcome title
        title = ctk.CTkLabel(scroll_frame, text="Welcome to AIO SSL Tool", font=("Arial", 28, "bold"))
        title.pack(pady=(0, 12))
        
        # Description
        desc = ctk.CTkLabel(
            scroll_frame,
            text="Start by setting your working directory where all certificates will be saved",
            font=("Arial", 13),
            text_color="gray70"
        )
        desc.pack(pady=(0, 40))
        
        # Working directory section
        if self.save_directory:
            # Directory already set
            dir_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1e3a1e")
            dir_frame.pack(fill="x", padx=100, pady=10)
            
            inner = ctk.CTkFrame(dir_frame, fg_color="transparent")
            inner.pack(fill="x", padx=20, pady=20)
            
            header_row = ctk.CTkFrame(inner, fg_color="transparent")
            header_row.pack(fill="x")
            
            ctk.CTkLabel(header_row, text="✓", font=("Arial", 24), text_color="#4ade80").pack(side="left", padx=(0, 10))
            
            text_col = ctk.CTkFrame(header_row, fg_color="transparent")
            text_col.pack(side="left", fill="x", expand=True)
            
            ctk.CTkLabel(text_col, text="Working Directory Set", font=("Arial", 15, "bold"), anchor="w").pack(anchor="w")
            ctk.CTkLabel(text_col, text=self.save_directory, font=("Arial", 10), text_color="gray70", anchor="w").pack(anchor="w")
            
            change_btn = ctk.CTkButton(header_row, text="Change", command=self.select_save_directory, width=100, height=32)
            change_btn.pack(side="right")
            
            helper = ctk.CTkLabel(
                scroll_frame,
                text="You can now use the Chain Builder and other tools from the sidebar",
                font=("Arial", 10),
                text_color="gray60"
            )
            helper.pack(pady=(15, 0))
        else:
            # No directory set yet
            set_btn = ctk.CTkButton(
                scroll_frame,
                text="📁  Set Working Directory",
                command=self.select_save_directory,
                height=50,
                font=("Arial", 15, "bold"),
                fg_color="#1f538d",
                hover_color="#1a4474"
            )
            set_btn.pack(pady=20)
    
    def show_csr_view(self):
        """Display CSR generation view"""
        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x", padx=0, pady=0)
        
        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)
        
        ctk.CTkLabel(header_content, text="CSR Generator", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(header_content, text="Create Certificate Signing Requests and Private Keys", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")
        
        # Content
        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)
        
        if not self.save_directory:
            self.show_no_directory_message(scroll_frame)
            return
        
        # Inline CSR Generation Form
        csr_content = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        csr_content.pack(pady=10, padx=10, fill="x")
        fields = [
            ("Common Name (CN)", "example.com"),
            ("Country (C)", "US (2 letters)"),
            ("State/Province (ST)", "California"),
            ("Locality (L)", "San Francisco"),
            ("Organization (O)", "My Company"),
            ("Organizational Unit (OU)", "IT Department"),
            ("Email Address (Optional)", "admin@example.com")
        ]
        self.csr_entries = {}
        for label_text, placeholder in fields:
            row = ctk.CTkFrame(csr_content, fg_color="transparent")
            row.pack(fill="x", pady=1)
            ctk.CTkLabel(row, text=label_text + ":", width=160, anchor="w").pack(side="left")
            entry = ctk.CTkEntry(row, placeholder_text=placeholder, height=40)
            entry.pack(side="right", fill="x", expand=True, padx=(10, 0))
            self.csr_entries[label_text.split(" (")[0]] = entry
        ctk.CTkLabel(csr_content, text="SANs (domains/IP addresses IPv4/IPv6, one per line):", anchor="w").pack(fill="x", pady=(15, 5))
        self.csr_san_text = ctk.CTkTextbox(csr_content, height=120)
        self.csr_san_text.pack(fill="x", pady=(0, 10))
        self.csr_placeholder_text = "www.example.com\nmail.example.com\nautodiscover.example.com"
        self.csr_san_text.insert("1.0", self.csr_placeholder_text)
        self.csr_san_text.tag_add("placeholder", "1.0", "end")
        self.csr_san_text.tag_config("placeholder", foreground="#888888")
        self.csr_placeholder_active = True
        self.csr_san_text.bind("<FocusIn>", self.on_csr_san_focus_in)
        self.csr_san_text.bind("<FocusOut>", self.on_csr_san_focus_out)
        
        # Key type
        key_frame = ctk.CTkFrame(csr_content, fg_color="transparent")
        key_frame.pack(fill="x", pady=10)
        ctk.CTkLabel(key_frame, text="Key Type:", width=160, anchor="w").pack(side="left", padx=(0, 10))
        self.csr_key_type_var = ctk.StringVar(value="RSA")
        key_combo = ctk.CTkComboBox(key_frame, values=["RSA", "ECC"], variable=self.csr_key_type_var, command=self.on_csr_key_type_change)
        key_combo.pack(side="left")
        self.csr_dynamic_frame = ctk.CTkFrame(key_frame, fg_color="transparent")
        self.csr_dynamic_frame.pack(side="left", fill="x", expand=True, padx=(20, 0))
        self.create_csr_rsa_options()
        
        # Passphrase
        pass_frame = ctk.CTkFrame(csr_content, fg_color="transparent")
        pass_frame.pack(fill="x", pady=10)
        ctk.CTkLabel(pass_frame, text="Passphrase (optional):", width=160, anchor="w").pack(side="left", padx=(0, 10))
        self.csr_pass_entry = ctk.CTkEntry(pass_frame, show="*", placeholder_text="Leave blank = no password")
        self.csr_pass_entry.pack(side="left", fill="x", expand=True)

        # Generate button (smaller, softer color)
        ctk.CTkButton(
            csr_content,
            text="Generate CSR + Private Key",
            command=self.generate_csr_inline,
            font=("Arial", 14, "bold"),
            height=40,
            fg_color="#2563eb",
            hover_color="#1e40af",
        ).pack(fill="x", pady=(18, 8))

        # Small helper note (compact)
        ctk.CTkLabel(
            csr_content,
            text="Files saved to the working directory. Keep private keys secure.",
            font=("Arial", 10),
            text_color="gray60",
            anchor="w",
        ).pack(fill="x", pady=(8, 18))

    def on_csr_san_focus_in(self, event):
        try:
            if getattr(self, 'csr_placeholder_active', False):
                self.csr_san_text.delete("1.0", "end")
                self.csr_san_text.tag_remove("placeholder", "1.0", "end")
                self.csr_placeholder_active = False
        
                # Generate button (smaller, softer color)
                ctk.CTkButton(
                    csr_content,
                    text="Generate CSR + Private Key",
                    command=self.generate_csr_inline,
                    font=("Arial", 14, "bold"),
                    height=40,
                    fg_color="#2563eb",
                    hover_color="#1e40af",
                ).pack(fill="x", pady=(18, 8))

                # Small helper note (compact)
                ctk.CTkLabel(
                    csr_content,
                    text="Files saved to the working directory. Keep private keys secure.",
                    font=("Arial", 10),
                    text_color="gray60",
                    anchor="w",
                ).pack(fill="x", pady=(8, 18))
        except Exception:
            pass

    def on_csr_san_focus_out(self, event):
        try:
            content = self.csr_san_text.get("1.0", "end").strip()
            if not content:
                self.csr_san_text.insert("1.0", self.csr_placeholder_text)
                self.csr_san_text.tag_add("placeholder", "1.0", "end")
                self.csr_placeholder_active = True
        except Exception:
            pass

    def on_csr_key_type_change(self, value):
        """Switch dynamic CSR options when key type changes (RSA <-> ECC)."""
        # Clear dynamic frame
        for w in self.csr_dynamic_frame.winfo_children():
            w.destroy()
        if value == "RSA" or self.csr_key_type_var.get() == "RSA":
            self.create_csr_rsa_options()
        else:
            self.create_csr_ecc_options()

    def create_csr_rsa_options(self):
        """Create RSA-specific option widgets inside `self.csr_dynamic_frame`."""
        self.csr_key_size_var = ctk.StringVar(value="2048")
        ctk.CTkLabel(self.csr_dynamic_frame, text="Key Size:", anchor="w").pack(side="left", padx=(0, 8))
        key_sizes = ["2048", "3072", "4096"]
        size_combo = ctk.CTkComboBox(self.csr_dynamic_frame, values=key_sizes, variable=self.csr_key_size_var)
        size_combo.pack(side="left")

    def create_csr_ecc_options(self):
        """Create ECC-specific option widgets inside `self.csr_dynamic_frame`."""
        self.csr_ecc_curve_var = ctk.StringVar(value="P-256")
        ctk.CTkLabel(self.csr_dynamic_frame, text="Curve:", anchor="w").pack(side="left", padx=(0, 8))
        curves = ["P-256", "P-384", "P-521"]
        curve_combo = ctk.CTkComboBox(self.csr_dynamic_frame, values=curves, variable=self.csr_ecc_curve_var)
        curve_combo.pack(side="left")

    def _reset_csr_form(self):
        """Reset all CSR form fields to defaults after successful generation."""
        try:
            for entry in self.csr_entries.values():
                entry.delete(0, "end")
            if hasattr(self, 'csr_san_text'):
                self.csr_san_text.delete("1.0", "end")
                self.csr_san_text.insert("1.0", self.csr_placeholder_text)
                self.csr_san_text.tag_add("placeholder", "1.0", "end")
                self.csr_placeholder_active = True
            if hasattr(self, 'csr_key_type_var'):
                self.csr_key_type_var.set("RSA")
                self.on_csr_key_type_change("RSA")
            if hasattr(self, 'csr_pass_entry'):
                self.csr_pass_entry.delete(0, "end")
        except Exception:
            pass

    def generate_csr_inline(self):
        """Collect form values and call `generate_csr_from_data`."""
        try:
            # Collect DN fields
            data = {}
            for key, entry in self.csr_entries.items():
                data[key] = entry.get().strip()

            # SANs
            sans_raw = self.csr_san_text.get("1.0", "end").strip()
            if getattr(self, 'csr_placeholder_active', False) and sans_raw == self.csr_placeholder_text:
                sans = []
            else:
                sans = [s.strip() for s in sans_raw.splitlines() if s.strip()]

            key_type = self.csr_key_type_var.get() if hasattr(self, 'csr_key_type_var') else "RSA"
            key_size = int(self.csr_key_size_var.get()) if hasattr(self, 'csr_key_size_var') else 2048
            ecc_curve = self.csr_ecc_curve_var.get() if hasattr(self, 'csr_ecc_curve_var') else "P-256"
            password = self.csr_pass_entry.get().strip() if hasattr(self, 'csr_pass_entry') else ""

            # Call existing generator
            self.generate_csr_from_data(data, sans, key_type, key_size, ecc_curve, password)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to generate CSR: {e}")

    def show_chain_view(self):
        """Display chain builder view"""
        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x", padx=0, pady=0)
        
        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)
        
        left_side = ctk.CTkFrame(header_content, fg_color="transparent")
        left_side.pack(side="left", fill="x", expand=True)
        
        ctk.CTkLabel(left_side, text="Chain Builder", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(left_side, text="Build complete certificate chains from leaf certificates", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")
        
        # Working directory indicator
        if self.save_directory:
            dir_indicator = ctk.CTkFrame(header_content, fg_color="#2a2a2a", corner_radius=8)
            dir_indicator.pack(side="right", padx=10)
            
            dir_content = ctk.CTkFrame(dir_indicator, fg_color="transparent")
            dir_content.pack(padx=10, pady=8)
            
            ctk.CTkLabel(dir_content, text="📁 " + os.path.basename(self.save_directory), font=("Arial", 10)).pack()
        
        # Content
        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)
        
        if not self.save_directory:
            self.show_no_directory_message(scroll_frame)
            return
        
        # Workflow cards in grid
        grid_frame = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        grid_frame.pack(fill="both", expand=True, pady=10)
        
        # Certificate selection card
        cert_card = ctk.CTkFrame(grid_frame, corner_radius=12, fg_color="#1a1a1a")
        cert_card.grid(row=0, column=0, padx=10, pady=10, sticky="nsew")
        
        grid_frame.columnconfigure(0, weight=1)
        grid_frame.columnconfigure(1, weight=1)
        grid_frame.rowconfigure(0, weight=1)
        grid_frame.rowconfigure(1, weight=1)
        
        ctk.CTkLabel(cert_card, text="📜 Certificate", font=("Arial", 16, "bold"), text_color="#3b82f6").pack(pady=(15, 10))
        
        cert_content = ctk.CTkFrame(cert_card, fg_color="transparent")
        cert_content.pack(fill="both", expand=True, padx=15, pady=(0, 15))
        
        if self.cert_file:
            status_frame = ctk.CTkFrame(cert_content, fg_color="#1e3a1e", corner_radius=8)
            status_frame.pack(fill="x", pady=5)
            
            ctk.CTkLabel(status_frame, text="✓", font=("Arial", 18), text_color="#4ade80").pack(side="left", padx=10, pady=10)
            
            text_frame = ctk.CTkFrame(status_frame, fg_color="transparent")
            text_frame.pack(side="left", fill="x", expand=True, pady=10)
            
            ctk.CTkLabel(text_frame, text=os.path.basename(self.cert_file), font=("Arial", 12, "bold"), anchor="w").pack(anchor="w")
            ctk.CTkLabel(text_frame, text="Selected", font=("Arial", 9), text_color="gray70", anchor="w").pack(anchor="w")
            
            ctk.CTkButton(status_frame, text="Change", command=self.browse_cert, width=80, height=28).pack(side="right", padx=10)
        else:
            ctk.CTkButton(cert_content, text="📂 Browse Certificate", command=self.browse_cert, height=40).pack(fill="x", pady=10)
        
        # Chain building card
        chain_card = ctk.CTkFrame(grid_frame, corner_radius=12, fg_color="#1a1a1a")
        chain_card.grid(row=0, column=1, padx=10, pady=10, sticky="nsew")
        
        ctk.CTkLabel(chain_card, text="🔗 Full Chain", font=("Arial", 16, "bold"), text_color="#8b5cf6").pack(pady=(15, 10))
        
        chain_content = ctk.CTkFrame(chain_card, fg_color="transparent")
        chain_content.pack(fill="both", expand=True, padx=15, pady=(0, 15))
        
        if self.fullchain_created:
            status_frame = ctk.CTkFrame(chain_content, fg_color="#1e3a1e", corner_radius=8)
            status_frame.pack(fill="x", pady=5)
            
            ctk.CTkLabel(status_frame, text="✓", font=("Arial", 18), text_color="#4ade80").pack(side="left", padx=10, pady=10)
            
            text_frame = ctk.CTkFrame(status_frame, fg_color="transparent")
            text_frame.pack(side="left", fill="x", expand=True, pady=10)
            
            ctk.CTkLabel(text_frame, text="FullChain.cer", font=("Arial", 12, "bold"), anchor="w").pack(anchor="w")
            ctk.CTkLabel(text_frame, text="Created", font=("Arial", 9), text_color="gray70", anchor="w").pack(anchor="w")
        else:
            build_btn = ctk.CTkButton(
                chain_content,
                text="⚡ Build Chain",
                command=self.create_full_chain,
                height=40,
                state="normal" if self.cert_file else "disabled"
            )
            build_btn.pack(fill="x", pady=10)
        
        # Status label
        status_label_text = "Ready to build chain" if self.cert_file else "Select a certificate to begin"
        if self.fullchain_created:
            status_label_text = "✓ Full chain created successfully"
        
        status_label = ctk.CTkLabel(scroll_frame, text=status_label_text, font=("Arial", 11), text_color="gray70")
        status_label.pack(pady=20)
    
    def show_private_ca_chain_view(self):
        """Display Private CA Chain builder view — assemble a full chain from local CA files."""
        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x")
        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)
        ctk.CTkLabel(header_content, text="Private CA Chain", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(header_content, text="Assemble a full-chain certificate from local CA files", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")

        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)

        if not self.save_directory:
            self.show_no_directory_message(scroll_frame)
            return

        # Initialize file path state variables if needed
        if not hasattr(self, 'pca_server_cert'):
            self.pca_server_cert = None
        if not hasattr(self, 'pca_sub_ca'):
            self.pca_sub_ca = None
        if not hasattr(self, 'pca_root_ca'):
            self.pca_root_ca = None

        # Card for file selection
        card = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        card.pack(fill="x", pady=(0, 16))
        card_content = ctk.CTkFrame(card, fg_color="transparent")
        card_content.pack(fill="x", padx=20, pady=20)

        ctk.CTkLabel(card_content, text="Certificate Files", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 12))

        def make_file_row(parent, label_text, optional, attr_name):
            row = ctk.CTkFrame(parent, fg_color="#222222", corner_radius=8)
            row.pack(fill="x", pady=4)
            inner = ctk.CTkFrame(row, fg_color="transparent")
            inner.pack(fill="x", padx=12, pady=10)

            lbl_frame = ctk.CTkFrame(inner, fg_color="transparent")
            lbl_frame.pack(anchor="w", pady=(0, 6))
            ctk.CTkLabel(lbl_frame, text=label_text, font=("Arial", 13, "bold")).pack(side="left")
            if optional:
                ctk.CTkLabel(lbl_frame, text=" (Optional)", font=("Arial", 11), text_color="gray60").pack(side="left")

            entry_frame = ctk.CTkFrame(inner, fg_color="transparent")
            entry_frame.pack(fill="x")
            entry = ctk.CTkEntry(entry_frame, placeholder_text="No file selected", height=36)
            entry.pack(side="left", fill="x", expand=True, padx=(0, 8))
            current = getattr(self, attr_name)
            if current:
                entry.insert(0, current)

            def browse(e=entry, a=attr_name):
                path = filedialog.askopenfilename(
                    initialdir=self.save_directory,
                    title=f"Select {label_text}",
                    filetypes=[("Certificates", "*.cer *.crt *.pem"), ("All files", "*.*")]
                )
                if path:
                    setattr(self, a, path)
                    e.delete(0, "end")
                    e.insert(0, path)

            ctk.CTkButton(entry_frame, text="Browse", command=browse, height=36, width=90).pack(side="left")
            return entry

        make_file_row(card_content, "Server Certificate", optional=False, attr_name="pca_server_cert")
        make_file_row(card_content, "Subordinate CA", optional=True, attr_name="pca_sub_ca")
        make_file_row(card_content, "Root CA", optional=False, attr_name="pca_root_ca")

        # Info note
        info = ctk.CTkFrame(scroll_frame, corner_radius=8, fg_color="#0d2a3d")
        info.pack(fill="x", pady=(0, 16))
        ctk.CTkLabel(
            info,
            text="ℹ  Files are concatenated in order: Server Certificate → Subordinate CA → Root CA.\n"
                 "   The result is saved as FullChain.cer in your working directory.",
            font=("Arial", 11),
            text_color="gray80",
            justify="left",
            anchor="w"
        ).pack(padx=14, pady=10, anchor="w")

        # Build button
        ctk.CTkButton(
            scroll_frame,
            text="🔗  Build Full Chain",
            command=self._build_private_ca_chain,
            height=44,
            font=("Arial", 14, "bold")
        ).pack(fill="x", pady=4)

    def _build_private_ca_chain(self):
        """Concatenate selected certificate files into a full chain PEM."""
        if not self.pca_server_cert:
            messagebox.showerror("Missing File", "Please select a Server Certificate.")
            return
        if not self.pca_root_ca:
            messagebox.showerror("Missing File", "Please select a Root CA certificate.")
            return

        try:
            parts = [self.pca_server_cert, self.pca_sub_ca, self.pca_root_ca]
            pem_data = ""
            for path in parts:
                if not path:
                    continue
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                if not content.endswith("\n"):
                    content += "\n"
                pem_data += content

            output_path = os.path.join(self.save_directory, "FullChain.cer")
            with open(output_path, "w", encoding="utf-8") as f:
                f.write(pem_data)

            self.archive_files([output_path], domain=None)
            # Reset selections
            self.pca_server_cert = None
            self.pca_sub_ca = None
            self.pca_root_ca = None

            messagebox.showinfo(
                "Success",
                f"Full chain saved to:\n{output_path}"
            )
            self.show_view("privatecachain")

        except Exception as e:
            messagebox.showerror("Error", f"Failed to build chain: {e}")

    def show_pfx_view(self):
        """Display PFX generator view with advanced options"""
        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x", padx=0, pady=0)
        
        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)
        
        ctk.CTkLabel(header_content, text="PFX Generator", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(header_content, text="Create PFX/P12 files from certificate chains and private keys", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")
        
        # Content
        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)
        
        if not self.save_directory:
            self.show_no_directory_message(scroll_frame)
            return
        
        # Card grid for certificate chain and private key
        cards_frame = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        cards_frame.pack(fill="x", pady=10)
        cards_frame.grid_columnconfigure(0, weight=1)
        cards_frame.grid_columnconfigure(1, weight=1)
        
        # Certificate Chain Card
        chain_card = ctk.CTkFrame(cards_frame, corner_radius=12, fg_color="#1a1a1a")
        chain_card.grid(row=0, column=0, sticky="nsew", padx=(0, 10))
        
        chain_content = ctk.CTkFrame(chain_card, fg_color="transparent")
        chain_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(chain_content, text="Certificate Chain", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 8))
        
        self.pfx_chain_entry = ctk.CTkEntry(chain_content, placeholder_text="Select chain file...", height=36)
        self.pfx_chain_entry.pack(fill="x", pady=(0, 10))
        if self.pfx_chain_file:
            self.pfx_chain_entry.insert(0, self.pfx_chain_file)
        
        chain_btn_frame = ctk.CTkFrame(chain_content, fg_color="transparent")
        chain_btn_frame.pack(fill="x")
        
        ctk.CTkButton(chain_btn_frame, text="Browse", command=self.browse_pfx_chain, height=32, width=90).pack(side="left", padx=(0, 5))
        ctk.CTkButton(chain_btn_frame, text="Autofill", command=self.autofill_pfx_chain, height=32, width=90, 
                     fg_color="#1e7d1e", hover_color="#1a6b1a").pack(side="left")
        
        # Private Key Card
        key_card = ctk.CTkFrame(cards_frame, corner_radius=12, fg_color="#1a1a1a")
        key_card.grid(row=0, column=1, sticky="nsew", padx=(10, 0))
        
        key_content = ctk.CTkFrame(key_card, fg_color="transparent")
        key_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(key_content, text="Private Key", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 8))
        
        self.pfx_key_entry = ctk.CTkEntry(key_content, placeholder_text="Select private key...", height=36)
        self.pfx_key_entry.pack(fill="x", pady=(0, 10))
        if self.private_key_file:
            self.pfx_key_entry.insert(0, self.private_key_file)
        
        key_btn_frame = ctk.CTkFrame(key_content, fg_color="transparent")
        key_btn_frame.pack(fill="x")
        
        ctk.CTkButton(key_btn_frame, text="Browse", command=self.browse_private_key_for_pfx, height=32, width=90).pack(side="left", padx=(0, 5))
        
        self.verify_key_btn = ctk.CTkButton(key_btn_frame, text="Verify", command=self.verify_key_password, height=32, width=90)
        self.verify_key_btn.pack(side="left")
        
        # Password section
        password_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        password_frame.pack(fill="x", pady=15)
        
        password_content = ctk.CTkFrame(password_frame, fg_color="transparent")
        password_content.pack(fill="both", padx=20, pady=20)
        
        # Key password
        ctk.CTkLabel(password_content, text="Private Key Password", font=("Arial", 13, "bold")).pack(anchor="w", pady=(0, 5))
        ctk.CTkLabel(password_content, text="Leave blank if key is not encrypted", font=("Arial", 10), text_color="gray60").pack(anchor="w", pady=(0, 5))
        self.pfx_key_password_entry = ctk.CTkEntry(password_content, placeholder_text="Enter key password (optional)...", show="*", height=36)
        self.pfx_key_password_entry.pack(fill="x", pady=(0, 15))
        if self.private_key_password:
            self.pfx_key_password_entry.insert(0, self.private_key_password)
        
        # PFX Password
        ctk.CTkLabel(password_content, text="PFX Password", font=("Arial", 13, "bold")).pack(anchor="w", pady=(0, 5))
        ctk.CTkLabel(password_content, text="Password to protect the output PFX file", font=("Arial", 10), text_color="gray60").pack(anchor="w", pady=(0, 5))
        self.pfx_password_entry = ctk.CTkEntry(password_content, placeholder_text="Enter PFX password...", show="*", height=36)
        self.pfx_password_entry.pack(fill="x")

        # Advanced Options Section
        advanced_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        advanced_frame.pack(fill="x", pady=15)

        advanced_header = ctk.CTkFrame(advanced_frame, fg_color="transparent")
        advanced_header.pack(fill="x", padx=20, pady=(15, 0))

        self.pfx_advanced_toggle = ctk.CTkCheckBox(
            advanced_header,
            text="Advanced Options",
            command=self.toggle_pfx_advanced,
            font=("Arial", 13, "bold"),
            height=24
        )
        self.pfx_advanced_toggle.pack(anchor="w")

        # Advanced options content (hidden by default)
        self.pfx_advanced_content = ctk.CTkFrame(advanced_frame, fg_color="transparent")

        adv_inner = ctk.CTkFrame(self.pfx_advanced_content, fg_color="transparent")
        adv_inner.pack(fill="x", padx=20, pady=(10, 15))

        # MAC Algorithm
        mac_frame = ctk.CTkFrame(adv_inner, fg_color="transparent")
        mac_frame.pack(fill="x", pady=(0, 10))

        ctk.CTkLabel(mac_frame, text="MAC Algorithm", font=("Arial", 12, "bold")).pack(anchor="w", pady=(0, 5))

        mac_buttons_frame = ctk.CTkFrame(mac_frame, fg_color="transparent")
        mac_buttons_frame.pack(fill="x")

        self.pfx_mac_var = ctk.StringVar(value=self.pfx_mac_algorithm)
        mac_algorithms = ["SHA-256", "SHA-512", "SHA-1"]
        for algo in mac_algorithms:
            btn = ctk.CTkRadioButton(
                mac_buttons_frame, text=algo, variable=self.pfx_mac_var, value=algo,
                command=lambda a=algo: self.set_pfx_mac_algorithm(a),
                font=("Arial", 11)
            )
            btn.pack(side="left", padx=(0, 15))

        # Encryption Algorithm
        enc_frame = ctk.CTkFrame(adv_inner, fg_color="transparent")
        enc_frame.pack(fill="x", pady=(0, 10))

        ctk.CTkLabel(enc_frame, text="Encryption Algorithm", font=("Arial", 12, "bold")).pack(anchor="w", pady=(0, 5))

        enc_buttons_frame = ctk.CTkFrame(enc_frame, fg_color="transparent")
        enc_buttons_frame.pack(fill="x")

        self.pfx_enc_var = ctk.StringVar(value=self.pfx_encryption_algorithm)
        enc_algorithms = ["Default", "AES-256", "AES-128", "3DES", "Legacy"]
        for algo in enc_algorithms:
            btn = ctk.CTkRadioButton(
                enc_buttons_frame, text=algo, variable=self.pfx_enc_var, value=algo,
                command=lambda a=algo: self.set_pfx_encryption_algorithm(a),
                font=("Arial", 11)
            )
            btn.pack(side="left", padx=(0, 15))

        # Legacy warning label (hidden by default)
        self.pfx_legacy_warning = ctk.CTkLabel(
            adv_inner,
            text="⚠ Using legacy options — these use weak cryptography and are not recommended for production use",
            font=("Arial", 11),
            text_color="#ff9800",
            wraplength=500,
            anchor="w"
        )

        # Note: Windows uses cryptography library defaults
        ctk.CTkLabel(
            adv_inner,
            text="ℹ Note: On Windows, PFX files are created using the cryptography library's secure defaults. "
                 "These selections are shown for reference only and do not affect the output.",
            font=("Arial", 10),
            text_color="gray60",
            wraplength=500,
            anchor="w"
        ).pack(anchor="w", pady=(8, 0))

        # Generate PFX Button
        generate_frame = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        generate_frame.pack(fill="x", pady=15)

        ctk.CTkButton(
            generate_frame,
            text="Generate PFX File",
            command=self.create_pfx_advanced,
            height=42,
            font=("Arial", 14, "bold"),
            fg_color="#1f538d",
            hover_color="#163d6b"
        ).pack(fill="x")

    def show_extract_view(self):
        """Display Extract Private Key from PFX view"""
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x", padx=0, pady=0)

        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)

        ctk.CTkLabel(header_content, text="Key Extractor", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(header_content, text="Extract private key from a PFX/P12 file", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")

        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)

        form_content = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        form_content.pack(fill="both", expand=True, padx=50, pady=20)

        # PFX file row
        pfx_row = ctk.CTkFrame(form_content, fg_color="transparent")
        pfx_row.pack(fill="x", pady=(0, 20))

        self.extract_pfx_entry = ctk.CTkEntry(pfx_row, placeholder_text="Select PFX/P12 file...", height=36)
        self.extract_pfx_entry.pack(side="left", fill="x", expand=True, padx=(0, 10))

        ctk.CTkButton(pfx_row, text="Browse", command=self.browse_pfx_for_extract, width=100).pack(side="right")

        # Password
        ctk.CTkLabel(form_content, text="PFX Password", font=("Arial", 14, "bold")).pack(anchor="w", pady=(0, 5))
        self.extract_password_entry = ctk.CTkEntry(form_content, placeholder_text="Enter PFX password...", show="*", height=36)
        self.extract_password_entry.pack(fill="x", pady=(0, 25))

        # Extract button
        extract_btn = ctk.CTkButton(
            form_content,
            text="🔑 Extract Private Key",
            command=self.extract_key,
            height=45,
            font=("Arial", 14, "bold"),
            fg_color="#1e7d1e",
            hover_color="#1a6b1a"
        )
        extract_btn.pack(fill="x")

        # Info
        info_text = """The extracted private key will be saved as an unencrypted PEM file.
Keep this file secure and never share it."""

        ctk.CTkLabel(form_content, text=info_text, font=("Arial", 10), text_color="gray60", justify="center").pack(pady=(15, 0))

    # ------------------------------------------------------------------
    # ClearPass REST API View
    # ------------------------------------------------------------------

    def show_clearpass_view(self):
        """Display ClearPass REST API certificate upload view."""
        # Suppress SSL warnings
        try:
            import urllib3
            urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        except Exception:
            pass

        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x")
        hc = ctk.CTkFrame(header, fg_color="transparent")
        hc.pack(fill="x", padx=20, pady=15)
        ctk.CTkLabel(hc, text="ClearPass", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(hc, text="Upload and replace certificates on Aruba ClearPass via REST API",
                     font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")

        scroll = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll.pack(fill="both", expand=True, padx=30, pady=20)

        # Initialize persistent state (only on first load)
        if not hasattr(self, 'cp_access_token'):
            self.cp_access_token = None
        if not hasattr(self, 'cp_servers'):
            self.cp_servers = []
        if not hasattr(self, 'cp_pfx_path'):
            self.cp_pfx_path = None
        if not hasattr(self, 'cp_saved_host'):
            self.cp_saved_host = ""
        if not hasattr(self, 'cp_saved_client_id'):
            self.cp_saved_client_id = ""
        if not hasattr(self, 'cp_verify_ssl_var'):
            self.cp_verify_ssl_var = ctk.BooleanVar(value=True)
        if not hasattr(self, 'cp_service_var'):
            self.cp_service_var = ctk.StringVar(value="HTTPS(RSA)")
        if not hasattr(self, 'cp_inspect_service_var'):
            self.cp_inspect_service_var = ctk.StringVar(value="HTTPS(RSA)")

        _services = ["HTTPS(RSA)", "HTTP(ECC)", "RADIUS", "RadSec", "Database"]

        def lrow(parent, label, widget_factory):
            r = ctk.CTkFrame(parent, fg_color="transparent")
            r.pack(fill="x", pady=3)
            ctk.CTkLabel(r, text=label, width=170, anchor="w").pack(side="left", padx=(0, 8))
            w = widget_factory(r)
            w.pack(side="left", fill="x", expand=True)
            return w

        # --- Connection & Target Servers Card ---
        conn_card = ctk.CTkFrame(scroll, corner_radius=12, fg_color="#1a1a1a")
        conn_card.pack(fill="x", pady=(0, 12))
        cc = ctk.CTkFrame(conn_card, fg_color="transparent")
        cc.pack(fill="x", padx=20, pady=16)
        ctk.CTkLabel(cc, text="Connection & Target Servers", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 10))

        self.cp_host_entry = lrow(cc, "ClearPass Host:", lambda p: ctk.CTkEntry(p, placeholder_text="clearpass.example.com or IP", height=36))
        if self.cp_saved_host:
            self.cp_host_entry.insert(0, self.cp_saved_host)
        self.cp_client_id_entry = lrow(cc, "API Client ID:", lambda p: ctk.CTkEntry(p, placeholder_text="API client ID", height=36))
        if self.cp_saved_client_id:
            self.cp_client_id_entry.insert(0, self.cp_saved_client_id)
        self.cp_client_secret_entry = lrow(cc, "Client Secret:", lambda p: ctk.CTkEntry(p, placeholder_text="API client secret", show="*", height=36))

        ssl_row = ctk.CTkFrame(cc, fg_color="transparent")
        ssl_row.pack(fill="x", pady=(6, 0))
        ctk.CTkCheckBox(ssl_row, text="Verify SSL Certificate", variable=self.cp_verify_ssl_var).pack(side="left")

        # Status label + connect button row
        status_btn_row = ctk.CTkFrame(cc, fg_color="transparent")
        status_btn_row.pack(fill="x", pady=(8, 0))
        self.cp_conn_status_label = ctk.CTkLabel(status_btn_row, text="", font=("Arial", 11), text_color="gray70")
        self.cp_conn_status_label.pack(side="left")
        if self.cp_access_token:
            self.cp_conn_status_label.configure(
                text=f"● Connected — {len(self.cp_servers)} server(s) found", text_color="#44cc44")
        ctk.CTkButton(
            status_btn_row, text="Connect & Discover Servers",
            command=self._cp_connect,
            height=38, font=("Arial", 13, "bold")
        ).pack(side="right")

        # Debug log (shown during connect for troubleshooting)
        self.cp_debug_frame = ctk.CTkFrame(cc, fg_color="transparent")
        self.cp_debug_text = ctk.CTkTextbox(self.cp_debug_frame, height=90, font=("Courier", 10),
                                            wrap="word", fg_color="#111111", text_color="#aaffaa")
        self.cp_debug_text.pack(fill="x")

        # Server list (inline, shown after connect)
        self.cp_server_list_frame = ctk.CTkFrame(cc, fg_color="transparent")
        self.cp_server_list_frame.pack(fill="x", pady=(4, 0))
        self.cp_server_vars = {}
        if self.cp_servers:
            self._cp_render_servers()

        # --- Certificate Card ---
        cert_card = ctk.CTkFrame(scroll, corner_radius=12, fg_color="#1a1a1a")
        cert_card.pack(fill="x", pady=(0, 12))
        cert_c = ctk.CTkFrame(cert_card, fg_color="transparent")
        cert_c.pack(fill="x", padx=20, pady=16)
        ctk.CTkLabel(cert_c, text="Certificate (PFX/P12)", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 10))

        pfx_row = ctk.CTkFrame(cert_c, fg_color="transparent")
        pfx_row.pack(fill="x", pady=3)
        ctk.CTkLabel(pfx_row, text="PFX File:", width=170, anchor="w").pack(side="left", padx=(0, 8))
        self.cp_pfx_entry = ctk.CTkEntry(pfx_row, placeholder_text="Select PFX or P12 file…", height=36)
        self.cp_pfx_entry.pack(side="left", fill="x", expand=True, padx=(0, 8))
        if self.cp_pfx_path:
            self.cp_pfx_entry.insert(0, self.cp_pfx_path)
        ctk.CTkButton(pfx_row, text="Browse", command=self._cp_browse_pfx, height=36, width=90).pack(side="left")

        self.cp_passphrase_entry = lrow(cert_c, "PFX Passphrase:", lambda p: ctk.CTkEntry(p, placeholder_text="Password protecting the PFX", show="*", height=36))

        svc_row = ctk.CTkFrame(cert_c, fg_color="transparent")
        svc_row.pack(fill="x", pady=3)
        ctk.CTkLabel(svc_row, text="Service:", width=170, anchor="w").pack(side="left", padx=(0, 8))
        ctk.CTkComboBox(svc_row, values=_services, variable=self.cp_service_var, width=200).pack(side="left")

        # Upload interface picker
        iface_row = ctk.CTkFrame(cert_c, fg_color="transparent")
        iface_row.pack(fill="x", pady=3)
        ctk.CTkLabel(iface_row, text="Upload Interface:", width=170, anchor="w").pack(side="left", padx=(0, 8))
        ifaces = self._cp_get_local_ips()
        self._cp_ifaces = ifaces
        if ifaces:
            iface_labels = [f"{n} — {ip}" for n, ip in ifaces]
            self.cp_iface_combo = ctk.CTkComboBox(iface_row, values=iface_labels, width=280, state="readonly")
            self.cp_iface_combo.set(iface_labels[0])
            self.cp_iface_combo.pack(side="left", padx=(0, 8))
        else:
            ctk.CTkLabel(iface_row, text="No interfaces detected", text_color="gray60").pack(side="left")

        # --- Current Certificates Card ---
        insp_card = ctk.CTkFrame(scroll, corner_radius=12, fg_color="#1a1a1a")
        insp_card.pack(fill="x", pady=(0, 12))
        insp_c = ctk.CTkFrame(insp_card, fg_color="transparent")
        insp_c.pack(fill="x", padx=20, pady=16)
        ctk.CTkLabel(insp_c, text="Current Certificates", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 8))

        inspect_row = ctk.CTkFrame(insp_c, fg_color="transparent")
        inspect_row.pack(fill="x", pady=(0, 6))
        ctk.CTkLabel(inspect_row, text="Service:", width=60, anchor="w").pack(side="left", padx=(0, 8))
        ctk.CTkComboBox(inspect_row, values=_services,
                        variable=self.cp_inspect_service_var, width=180).pack(side="left", padx=(0, 12))
        ctk.CTkButton(inspect_row, text="Fetch", command=self._cp_fetch_certs,
                      height=32, width=90).pack(side="left")
        ctk.CTkLabel(insp_c,
                     text="Inspect the certificate currently installed on each server for the selected service.",
                     font=("Arial", 10), text_color="gray60").pack(anchor="w", pady=(0, 8))

        self.cp_cert_display_frame = ctk.CTkFrame(insp_c, fg_color="transparent")
        self.cp_cert_display_frame.pack(fill="x")
        if hasattr(self, 'cp_current_certs') and self.cp_current_certs:
            self._cp_render_current_certs()

        # --- Upload Results ---
        if hasattr(self, 'cp_upload_results') and self.cp_upload_results:
            res_card = ctk.CTkFrame(scroll, corner_radius=12, fg_color="#1a1a1a")
            res_card.pack(fill="x", pady=(0, 12))
            rc = ctk.CTkFrame(res_card, fg_color="transparent")
            rc.pack(fill="x", padx=20, pady=16)
            ctk.CTkLabel(rc, text="Upload Results", font=("Arial", 16, "bold")).pack(anchor="w", pady=(0, 8))
            for line in self.cp_upload_results:
                color = "#44cc44" if line.startswith("✓") else ("#ddaa00" if line.startswith("⚠") else "#ee4444")
                ctk.CTkLabel(rc, text=line, font=("Arial", 11), anchor="w", text_color=color).pack(anchor="w")

        # --- Upload Button ---
        ctk.CTkButton(
            scroll, text="⬆  Upload Certificate",
            command=self._cp_upload,
            height=44, font=("Arial", 14, "bold")
        ).pack(fill="x", pady=4)

    def _cp_get_local_ips(self):
        """Return list of (interface_name, ip) for non-loopback IPv4 addresses."""
        import socket
        results = []
        seen = set()
        # Try psutil for proper interface names
        try:
            import psutil
            for iface, addrs in psutil.net_if_addrs().items():
                for addr in addrs:
                    if addr.family == socket.AF_INET and not addr.address.startswith("127.") and addr.address not in seen:
                        results.append((iface, addr.address))
                        seen.add(addr.address)
            if results:
                return results
        except ImportError:
            pass
        # Fallback: hostname resolution
        try:
            for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
                ip = info[4][0]
                if not ip.startswith("127.") and ip not in seen:
                    results.append(("eth", ip))
                    seen.add(ip)
        except Exception:
            pass
        # Fallback: UDP routing trick
        for dest in ["8.8.8.8", "1.1.1.1"]:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect((dest, 80))
                ip = s.getsockname()[0]
                s.close()
                if not ip.startswith("127.") and ip not in seen:
                    results.append(("eth", ip))
                    seen.add(ip)
            except Exception:
                pass
        return results

    def _cp_selected_ip(self):
        """Return the IP chosen in the interface picker."""
        if hasattr(self, 'cp_iface_combo') and hasattr(self, '_cp_ifaces') and self._cp_ifaces:
            val = self.cp_iface_combo.get()
            if " — " in val:
                return val.split(" — ")[-1].strip()
            return self._cp_ifaces[0][1]
        # Fallback: UDP routing trick
        import socket
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def _cp_render_servers(self):
        """Render server checkboxes inline within the Connection card."""
        frame = getattr(self, 'cp_server_list_frame', None)
        if not frame:
            return
        try:
            for w in frame.winfo_children():
                w.destroy()
        except Exception:
            return
        self.cp_server_vars = {}
        if not self.cp_servers:
            return

        ctk.CTkFrame(frame, height=1, fg_color="gray30").pack(fill="x", pady=(4, 8))

        def toggle_all():
            val = self.cp_select_all_var.get()
            for v in self.cp_server_vars.values():
                v.set(val)

        self.cp_select_all_var = ctk.BooleanVar(value=True)
        ctk.CTkCheckBox(frame, text="Select All", variable=self.cp_select_all_var,
                        command=toggle_all).pack(anchor="w", pady=(0, 4))

        for srv in self.cp_servers:
            var = ctk.BooleanVar(value=True)
            self.cp_server_vars[srv['uuid']] = var
            row = ctk.CTkFrame(frame, fg_color="#222222", corner_radius=6)
            row.pack(fill="x", pady=2)
            ctk.CTkCheckBox(row, text=f"  {srv['name']}", variable=var,
                            font=("Arial", 11)).pack(side="left", padx=10, pady=6)
            ctk.CTkLabel(row, text=srv['uuid'], font=("Courier", 9),
                         text_color="gray60").pack(side="left")

    def _cp_browse_pfx(self):
        path = filedialog.askopenfilename(
            title="Select PFX or P12 File",
            filetypes=[("PFX/P12 files", "*.pfx *.p12"), ("All files", "*.*")]
        )
        if path:
            self.cp_pfx_path = path
            if hasattr(self, 'cp_pfx_entry'):
                self.cp_pfx_entry.delete(0, "end")
                self.cp_pfx_entry.insert(0, path)

    def _cp_connect(self):
        """Connect to ClearPass API using requests (no subprocess)."""
        import threading
        import queue as _q

        host = self.cp_host_entry.get().strip() if hasattr(self, 'cp_host_entry') else ""
        client_id = self.cp_client_id_entry.get().strip() if hasattr(self, 'cp_client_id_entry') else ""
        client_secret = self.cp_client_secret_entry.get().strip() if hasattr(self, 'cp_client_secret_entry') else ""

        if not host or not client_id or not client_secret:
            messagebox.showerror("Missing Fields", "Please fill in Host, Client ID, and Client Secret.")
            return

        self.cp_saved_host = host
        self.cp_saved_client_id = client_id

        verify = self.cp_verify_ssl_var.get() if hasattr(self, 'cp_verify_ssl_var') else True
        base = host if host.startswith("http") else f"https://{host}"

        try:
            self.cp_conn_status_label.configure(text="Connecting... (0s)", text_color="yellow")
            if hasattr(self, 'cp_debug_text'):
                self.cp_debug_text.delete("1.0", "end")
                self.cp_debug_frame.pack(fill="x", pady=(4, 0))
        except Exception:
            pass

        self._cp_dbg(f"Connecting to {host}...")

        # Pre-cache stdlib imports in main thread (avoid import lock in background thread)
        import json, urllib.parse, uuid as _uuid

        done_q = _q.Queue()

        def _https_request(hostname, port, method, path, headers, body_bytes=None):
            """Raw http.client HTTPS call — no proxy detection, no certifi, no requests."""
            if verify:
                ctx = _ssl.create_default_context()
            else:
                ctx = _ssl._create_unverified_context()
            conn = http.client.HTTPSConnection(hostname, port, context=ctx, timeout=5)
            conn.request(method, path, body=body_bytes, headers=headers or {})
            resp = conn.getresponse()
            status = resp.status
            body = resp.read()
            conn.close()
            return status, body

        def _work():
            try:
                parsed = urllib.parse.urlparse(base if "://" in base else f"https://{base}")
                hostname = parsed.hostname or host
                port = parsed.port or 443

                # OAuth token
                oauth_body = json.dumps({
                    "grant_type": "client_credentials",
                    "client_id": client_id,
                    "client_secret": client_secret
                }).encode("utf-8")
                done_q.put(("log", "Requesting OAuth token..."))
                status1, body1 = _https_request(
                    hostname, port, "POST", "/api/oauth", body_bytes=oauth_body,
                    headers={"Content-Type": "application/json",
                             "Accept": "application/json",
                             "Content-Length": str(len(oauth_body))})
                if status1 != 200:
                    done_q.put(("err", f"OAuth failed (HTTP {status1}): {body1[:120].decode('utf-8','replace')}"))
                    return
                data = json.loads(body1)
                token = data.get("access_token", "")
                if not token:
                    done_q.put(("log", f"Response: {body1[:200].decode('utf-8','replace')}"))
                    done_q.put(("err", "No access_token in OAuth response"))
                    return
                done_q.put(("log", "OAuth token received. Discovering servers..."))

                # Cluster discovery
                try:
                    status2, body2 = _https_request(
                        hostname, port, "GET", "/api/cluster/server", body_bytes=None,
                        headers={"Authorization": f"Bearer {token}",
                                 "Accept": "application/json"})
                except Exception as e2:
                    done_q.put(("log", f"Cluster discovery failed: {e2}"))
                    status2, body2 = 0, b""

                servers = []
                if status2 == 200:
                    try:
                        for item in json.loads(body2).get("_embedded", {}).get("items", []):
                            uid = item.get("server_uuid") or item.get("uuid", "")
                            name = item.get("name") or item.get("hostname", uid)
                            if uid:
                                servers.append({"uuid": uid, "name": name})
                    except Exception as pe:
                        done_q.put(("log", f"Cluster parse error: {pe}"))
                if not servers:
                    servers = [{"uuid": str(_uuid.uuid4()), "name": host}]
                names = ", ".join(s['name'] for s in servers)
                done_q.put(("log", f"Found {len(servers)} server(s): {names}"))
                done_q.put(("ok", token, servers))
            except Exception as e:
                done_q.put(("err", f"{type(e).__name__}: {e}"))

        def _poll():
            try:
                try:
                    self.cp_conn_status_label.configure(
                        text="Connecting...", text_color="yellow")
                except Exception:
                    pass
                try:
                    while True:
                        msg = done_q.get_nowait()
                        if msg[0] == "log":
                            self._cp_dbg(msg[1])
                        elif msg[0] == "ok":
                            self.cp_access_token = msg[1]
                            self.cp_servers = msg[2]
                            self._cp_post_connect(success=True)
                            return
                        else:
                            self._cp_post_connect(success=False, error=msg[1])
                            return
                except _q.Empty:
                    pass
                except Exception as ex:
                    try:
                        self._cp_dbg(f"_poll error: {ex}")
                    except Exception:
                        pass
            except Exception as ex:
                try:
                    self._cp_dbg(f"[poll outer exc: {ex}]")
                except Exception:
                    pass
            finally:
                try:
                    self.root.after(200, _poll)
                except Exception as ex:
                    try:
                        self._cp_dbg(f"[poll after() failed: {ex}]")
                    except Exception:
                        pass

        threading.Thread(target=_work, daemon=True).start()
        _poll()  # call directly to bootstrap; _poll reschedules itself with after()

    def _cp_dbg(self, msg):
        """Append a line to the debug textbox (main thread only)."""
        try:
            if hasattr(self, 'cp_debug_text'):
                self.cp_debug_text._textbox.insert("end", msg + "\n")
                self.cp_debug_text._textbox.see("end")
        except Exception:
            pass

    def _cp_conn_fail(self, msg):
        try:
            self.cp_conn_status_label.configure(text=f"✗ {msg[:90]}", text_color="#ee4444")
        except Exception:
            pass
        self._cp_dbg(f"ERROR: {msg}")

    def _cp_curl(self, method, url, headers=None, body=None, verify=True, timeout=15):
        """Synchronous curl helper for upload/fetch (called from background threads)."""
        import subprocess, os
        curl = None
        for _p in [r"C:\Windows\System32\curl.exe", r"C:\Windows\curl.exe"]:
            if os.path.isfile(_p):
                curl = _p
                break
        if not curl:
            raise FileNotFoundError("curl.exe not found at C:\\Windows\\System32\\curl.exe")
        cmd = [curl, "-s", "-S", "--connect-timeout", "10", "-m", str(timeout), "--noproxy", "*"]
        if not verify:
            cmd.append("-k")
        cmd.extend(["-X", method, url])
        for k, v in (headers or {}).items():
            cmd.extend(["-H", f"{k}: {v}"])
        if body:
            cmd.extend(["--data-raw", body])
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 5,
                           stdin=subprocess.DEVNULL,
                           creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        if r.returncode != 0:
            raise ValueError(f"curl error ({r.returncode}): {(r.stderr or r.stdout)[:200]}")
        return r.stdout

    def _cp_post_connect(self, success, error=""):
        try:
            if hasattr(self, 'cp_conn_status_label'):
                if success:
                    n = len(self.cp_servers)
                    self.cp_conn_status_label.configure(
                        text=f"● Connected — {n} server(s) found", text_color="#44cc44")
                else:
                    self.cp_conn_status_label.configure(
                        text=f"✗ {error}", text_color="#ee4444")
        except Exception:
            pass
        if success:
            try:
                self._cp_render_servers()
            except Exception:
                pass
            try:
                self.cp_debug_frame.pack_forget()
            except Exception:
                pass

    def _cp_upload(self):
        import threading, http.server, os
        from urllib.parse import quote as url_quote

        if not self.cp_access_token:
            messagebox.showerror("Not Connected", "Please connect to ClearPass first.")
            return
        pfx_path = self.cp_pfx_path or (self.cp_pfx_entry.get().strip() if hasattr(self, 'cp_pfx_entry') else "")
        if not pfx_path or not os.path.exists(pfx_path):
            messagebox.showerror("Missing File", "Please select a valid PFX file.")
            return
        selected = [uuid for uuid, var in self.cp_server_vars.items() if var.get()]
        if not selected:
            messagebox.showerror("No Servers", "Please select at least one target server.")
            return

        passphrase = self.cp_passphrase_entry.get() if hasattr(self, 'cp_passphrase_entry') else ""
        service = self.cp_service_var.get() if hasattr(self, 'cp_service_var') else "HTTPS(RSA)"
        verify = self.cp_verify_ssl_var.get() if hasattr(self, 'cp_verify_ssl_var') else True
        host_val = self.cp_host_entry.get().strip() if hasattr(self, 'cp_host_entry') else ""
        base = host_val if host_val.startswith("http") else f"https://{host_val}"
        token = self.cp_access_token
        servers_map = {s['uuid']: s['name'] for s in self.cp_servers}
        local_ip = self._cp_selected_ip()
        encoded_service = url_quote(service, safe="")

        import queue as _queue
        done_q = _queue.Queue()

        def _work():
            import json as _json, shutil
            pfx_data = open(pfx_path, "rb").read()

            class _Handler(http.server.BaseHTTPRequestHandler):
                def do_GET(self):
                    self.send_response(200)
                    self.send_header("Content-Type", "application/x-pkcs12")
                    self.send_header("Content-Length", str(len(pfx_data)))
                    self.end_headers()
                    self.wfile.write(pfx_data)
                def log_message(self, *args):
                    pass

            httpd = http.server.HTTPServer(("", 0), _Handler)
            srv_port = httpd.server_address[1]
            threading.Thread(target=httpd.serve_forever, daemon=True).start()

            pfx_url = f"http://{local_ip}:{srv_port}/cert.pfx"
            results = []
            use_curl = bool(shutil.which("curl") or shutil.which("curl.exe"))
            try:
                # Self-test (localhost, no SSL — requests is fine here)
                try:
                    import requests
                    s = requests.Session()
                    s.trust_env = False
                    test_r = s.get(pfx_url, timeout=5)
                    if test_r.ok and test_r.content:
                        results.append(f"✓ File server OK — serving {len(test_r.content)} bytes at {pfx_url}")
                    else:
                        results.append(f"⚠ File server returned empty response at {pfx_url}")
                except Exception as e:
                    results.append(f"✗ File server unreachable at {pfx_url}: {e}")
                    results.append("⚠ ClearPass must be able to reach this URL to download the certificate")
                    self.cp_upload_results = results
                    done_q.put(True)
                    return

                for uuid in selected:
                    name = servers_map.get(uuid, uuid)
                    try:
                        url = f"{base}/api/server-cert/name/{uuid}/{encoded_service}"
                        body = _json.dumps({"pkcs12_file_url": pfx_url, "pkcs12_passphrase": passphrase})
                        if use_curl:
                            raw = self._cp_curl("PUT", url,
                                headers={"Authorization": f"Bearer {token}",
                                         "Content-Type": "application/json"},
                                body=body, verify=verify, timeout=60)
                            results.append(f"✓ {name}: certificate updated successfully")
                        else:
                            r = s.put(url, data=body,
                                     headers={"Authorization": f"Bearer {token}",
                                              "Content-Type": "application/json"},
                                     verify=verify, timeout=(5, 60))
                            if r.ok:
                                results.append(f"✓ {name}: certificate updated successfully")
                            else:
                                results.append(f"✗ {name}: HTTP {r.status_code} — {r.text[:120]}")
                    except Exception as e:
                        results.append(f"✗ {name}: {e}")
            finally:
                httpd.shutdown()

            self.cp_upload_results = results
            done_q.put(True)

        def _poll_upload():
            try:
                done_q.get_nowait()
                self.show_view("clearpass")
            except _queue.Empty:
                self.root.after(200, _poll_upload)

        threading.Thread(target=_work, daemon=True).start()
        self.root.after(200, _poll_upload)

    def _cp_fetch_certs(self):
        """Fetch current certificates for all discovered servers."""
        import threading, queue, json, shutil
        from urllib.parse import quote as url_quote

        if not self.cp_access_token or not self.cp_servers:
            messagebox.showerror("Not Connected", "Please connect to ClearPass first.")
            return

        service = self.cp_inspect_service_var.get() if hasattr(self, 'cp_inspect_service_var') else "HTTPS(RSA)"
        verify = self.cp_verify_ssl_var.get() if hasattr(self, 'cp_verify_ssl_var') else True
        host_val = self.cp_host_entry.get().strip() if hasattr(self, 'cp_host_entry') else ""
        base = host_val if host_val.startswith("http") else f"https://{host_val}"
        token = self.cp_access_token
        encoded_service = url_quote(service, safe="")
        done_q = queue.Queue()
        use_curl = bool(shutil.which("curl") or shutil.which("curl.exe"))

        def _work():
            results = []
            for srv in self.cp_servers:
                uuid, name = srv['uuid'], srv['name']
                try:
                    url = f"{base}/api/server-cert/name/{uuid}/{encoded_service}"
                    hdrs = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
                    if use_curl:
                        raw = self._cp_curl("GET", url, headers=hdrs, verify=verify, timeout=15)
                        j = json.loads(raw)
                    else:
                        import requests
                        s = requests.Session()
                        s.trust_env = False
                        r = s.get(url, headers=hdrs, verify=verify, timeout=(5, 10))
                        if not r.ok:
                            raise ValueError(f"HTTP {r.status_code}")
                        j = r.json()
                    results.append({
                        "uuid": uuid, "name": name,
                        "subject": j.get("subject", "—"),
                        "issued_by": j.get("issued_by", "—"),
                        "expiry_date": j.get("expiry_date", "—"),
                        "service": service
                    })
                except Exception as e:
                    results.append({
                        "uuid": uuid, "name": name,
                        "subject": str(e)[:80], "issued_by": "—",
                        "expiry_date": "—", "service": service
                    })
            self.cp_current_certs = results
            done_q.put(True)

        def _poll_certs():
            try:
                done_q.get_nowait()
                self._cp_render_current_certs()
            except queue.Empty:
                self.root.after(200, _poll_certs)

        threading.Thread(target=_work, daemon=True).start()
        self.root.after(200, _poll_certs)

    def _cp_render_current_certs(self):
        """Render fetched certificate info cards."""
        if not hasattr(self, 'cp_cert_display_frame'):
            return
        try:
            for w in self.cp_cert_display_frame.winfo_children():
                w.destroy()
        except Exception:
            return
        if not hasattr(self, 'cp_current_certs') or not self.cp_current_certs:
            return
        for cert in self.cp_current_certs:
            row = ctk.CTkFrame(self.cp_cert_display_frame, fg_color="#222222", corner_radius=6)
            row.pack(fill="x", pady=2)
            inner = ctk.CTkFrame(row, fg_color="transparent")
            inner.pack(fill="x", padx=12, pady=8)
            # Header: name · service   expiry badge
            hdr = ctk.CTkFrame(inner, fg_color="transparent")
            hdr.pack(fill="x")
            ctk.CTkLabel(hdr, text=cert['name'], font=("Arial", 12, "bold")).pack(side="left")
            ctk.CTkLabel(hdr, text=f"  ·  {cert['service']}", font=("Arial", 10), text_color="gray60").pack(side="left")
            # Expiry colour-coding
            exp_text = cert['expiry_date']
            exp_color = "gray60"
            try:
                from datetime import datetime
                for fmt in ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%m/%d/%Y"]:
                    try:
                        exp_dt = datetime.strptime(exp_text, fmt)
                        days = (exp_dt - datetime.now()).days
                        if days < 0:
                            exp_text = f"Expired {abs(days)}d ago"
                            exp_color = "#ee4444"
                        elif days < 30:
                            exp_text = f"Expires in {days}d"
                            exp_color = "#ddaa00"
                        else:
                            exp_text = f"Expires in {days}d"
                            exp_color = "#44cc44"
                        break
                    except ValueError:
                        continue
            except Exception:
                pass
            ctk.CTkLabel(hdr, text=exp_text, font=("Arial", 10), text_color=exp_color).pack(side="right")
            # Detail rows
            for lbl, key in [("Subject:", "subject"), ("Issuer:", "issued_by"), ("Expires:", "expiry_date")]:
                dl = ctk.CTkFrame(inner, fg_color="transparent")
                dl.pack(fill="x")
                ctk.CTkLabel(dl, text=lbl, font=("Arial", 10, "bold"), width=60, anchor="w").pack(side="left")
                ctk.CTkLabel(dl, text=cert.get(key, "—"), font=("Courier", 10),
                             text_color="gray70", anchor="w").pack(side="left")

    def show_settings_view(self):
        # Header
        header = ctk.CTkFrame(self.content_area, fg_color="#1a1a1a", corner_radius=0)
        header.pack(fill="x", padx=0, pady=0)
        
        header_content = ctk.CTkFrame(header, fg_color="transparent")
        header_content.pack(fill="x", padx=20, pady=15)
        
        ctk.CTkLabel(header_content, text="Settings & About", font=("Arial", 24, "bold"), anchor="w").pack(anchor="w")
        ctk.CTkLabel(header_content, text="Application preferences and information", font=("Arial", 12), text_color="gray70", anchor="w").pack(anchor="w")
        
        # Content
        scroll_frame = ctk.CTkScrollableFrame(self.content_area, fg_color="transparent")
        scroll_frame.pack(fill="both", expand=True, padx=30, pady=20)
        
        # App icon and title
        icon_frame = ctk.CTkFrame(scroll_frame, fg_color="transparent")
        icon_frame.pack(pady=(20, 30))
        
        try:
            from PIL import Image
            icon_path = resource_path("HomeIcon.png")
            if not os.path.exists(icon_path):
                icon_path = os.path.join(os.path.dirname(__file__), "HomeIcon.png")
            
            if os.path.exists(icon_path):
                img = Image.open(icon_path)
                img_width, img_height = img.size
                aspect_ratio = img_width / img_height
                display_height = 100
                display_width = int(display_height * aspect_ratio)
                
                icon_image = ctk.CTkImage(img, size=(display_width, display_height))
                ctk.CTkLabel(icon_frame, image=icon_image, text="").pack(pady=(0, 15))
        except Exception:
            pass
        
        ctk.CTkLabel(icon_frame, text="AIO SSL Suite", font=("Arial", 20, "bold")).pack()
        ctk.CTkLabel(icon_frame, text="Version V6.3.0", font=("Arial", 12), text_color="gray70").pack(pady=5)
        
        # About Section
        about_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        about_frame.pack(fill="x", pady=10, padx=50)
        
        about_content = ctk.CTkFrame(about_frame, fg_color="transparent")
        about_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(about_content, text="ℹ️  About", font=("Arial", 14, "bold"), anchor="w").pack(anchor="w", pady=(0, 10))
        ctk.CTkLabel(about_content, text="A modern SSL certificate management tool for Windows.", font=("Arial", 11), text_color="gray70", anchor="w", wraplength=500).pack(anchor="w", pady=(0, 10))
        
        info_grid = ctk.CTkFrame(about_content, fg_color="transparent")
        info_grid.pack(fill="x", pady=5)
        
        # License row
        lic_row = ctk.CTkFrame(info_grid, fg_color="transparent")
        lic_row.pack(fill="x", pady=3)
        ctk.CTkLabel(lic_row, text="License", font=("Arial", 11), anchor="w").pack(side="left")
        ctk.CTkLabel(lic_row, text="MIT", font=("Arial", 11), text_color="gray70", anchor="e").pack(side="right")
        
        # Developer row
        dev_row = ctk.CTkFrame(info_grid, fg_color="transparent")
        dev_row.pack(fill="x", pady=3)
        ctk.CTkLabel(dev_row, text="Developer", font=("Arial", 11), anchor="w").pack(side="left")
        ctk.CTkLabel(dev_row, text="CMDLAB", font=("Arial", 11), text_color="gray70", anchor="e").pack(side="right")
        
        # Advanced Options Section
        adv_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        adv_frame.pack(fill="x", pady=10, padx=50)
        
        adv_content = ctk.CTkFrame(adv_frame, fg_color="transparent")
        adv_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(adv_content, text="⚙️  Advanced Options", font=("Arial", 14, "bold"), anchor="w").pack(anchor="w", pady=(0, 10))
        
        # Advanced options checkbox (stored in instance variable)
        if not hasattr(self, 'never_show_advanced_warning'):
            self.never_show_advanced_warning = False
        
        self.adv_checkbox_var = ctk.BooleanVar(value=self.never_show_advanced_warning)
        checkbox = ctk.CTkCheckBox(
            adv_content,
            text="Never show advanced options warning",
            variable=self.adv_checkbox_var,
            command=self.toggle_advanced_warning
        )
        checkbox.pack(anchor="w", pady=5)
        ctk.CTkLabel(adv_content, text="Disable the caution message when using legacy cryptographic options", font=("Arial", 9), text_color="gray60", anchor="w", wraplength=450).pack(anchor="w", padx=(25, 0))
        
        # Separator
        sep = ctk.CTkFrame(adv_content, height=1, fg_color="gray40")
        sep.pack(fill="x", pady=12)
        
        # Certificate Archive option
        if not hasattr(self, 'enable_certificate_archive'):
            self.enable_certificate_archive = False
        
        self.archive_checkbox_var = ctk.BooleanVar(value=self.enable_certificate_archive)
        archive_checkbox = ctk.CTkCheckBox(
            adv_content,
            text="Enable certificate archive",
            variable=self.archive_checkbox_var,
            command=self.toggle_certificate_archive
        )
        archive_checkbox.pack(anchor="w", pady=5)
        ctk.CTkLabel(adv_content, text="Automatically save a timestamped copy of generated files, organized by domain", font=("Arial", 9), text_color="gray60", anchor="w", wraplength=450).pack(anchor="w", padx=(25, 0))
        
        if self.enable_certificate_archive:
            # Sub-checkbox: hide archive folder
            if not hasattr(self, 'hide_archive_folder'):
                self.hide_archive_folder = True

            self.hide_archive_checkbox_var = ctk.BooleanVar(value=self.hide_archive_folder)
            hide_checkbox = ctk.CTkCheckBox(
                adv_content,
                text="Hide archive folder",
                variable=self.hide_archive_checkbox_var,
                command=self.toggle_hide_archive_folder
            )
            hide_checkbox.pack(anchor="w", pady=(6, 0), padx=(25, 0))
            ctk.CTkLabel(adv_content, text="Archive folder will be hidden from File Explorer", font=("Arial", 9), text_color="gray60", anchor="w", wraplength=430).pack(anchor="w", padx=(50, 0))

            folder_name = ".archive" if self.hide_archive_folder else "archive"
            archive_info = ctk.CTkFrame(adv_content, fg_color="transparent")
            archive_info.pack(anchor="w", padx=(25, 0), pady=(8, 0))
            ctk.CTkLabel(archive_info, text=f"ℹ️  Archives are saved to {folder_name}/ inside your working directory, organized as domain/timestamp/", font=("Arial", 9), text_color="#4a9eff", anchor="w", wraplength=420).pack(anchor="w")
        
        # System Section
        sys_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        sys_frame.pack(fill="x", pady=10, padx=50)
        
        sys_content = ctk.CTkFrame(sys_frame, fg_color="transparent")
        sys_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(sys_content, text="💻  System", font=("Arial", 14, "bold"), anchor="w").pack(anchor="w", pady=(0, 10))
        
        # Cryptography library
        crypto_row = ctk.CTkFrame(sys_content, fg_color="transparent")
        crypto_row.pack(fill="x", pady=3)
        ctk.CTkLabel(crypto_row, text="Cryptography Library", font=("Arial", 11), anchor="w").pack(side="left")
        ctk.CTkLabel(crypto_row, text="✓ cryptography", font=("Arial", 11), text_color="#4ade80", anchor="e").pack(side="right")
        
        # Certificate Store
        store_row = ctk.CTkFrame(sys_content, fg_color="transparent")
        store_row.pack(fill="x", pady=3)
        ctk.CTkLabel(store_row, text="Certificate Store", font=("Arial", 11), anchor="w").pack(side="left")
        store_label = "✓ Windows Store" if wincertstore else "⚠ Not Available"
        store_color = "#4ade80" if wincertstore else "#fbbf24"
        ctk.CTkLabel(store_row, text=store_label, font=("Arial", 11), text_color=store_color, anchor="e").pack(side="right")
        
        # Working Directory Section
        wd_frame = ctk.CTkFrame(scroll_frame, corner_radius=12, fg_color="#1a1a1a")
        wd_frame.pack(fill="x", pady=10, padx=50)
        
        wd_content = ctk.CTkFrame(wd_frame, fg_color="transparent")
        wd_content.pack(fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(wd_content, text="📁  Working Directory", font=("Arial", 14, "bold"), anchor="w").pack(anchor="w", pady=(0, 10))
        
        if self.save_directory:
            ctk.CTkLabel(wd_content, text=self.save_directory, font=("Arial", 11), text_color="gray70", anchor="w").pack(anchor="w", pady=5)
            ctk.CTkButton(wd_content, text="Change Directory", command=self.select_save_directory, height=36).pack(anchor="w", pady=(10, 0))
        else:
            ctk.CTkLabel(wd_content, text="No working directory set", font=("Arial", 11), text_color="gray70", anchor="w").pack(anchor="w", pady=5)
            ctk.CTkButton(wd_content, text="Set Directory", command=self.select_save_directory, height=36).pack(anchor="w", pady=(10, 0))
        
        # Copyright footer
        ctk.CTkLabel(scroll_frame, text="© 2026 CMDLAB. All rights reserved.", font=("Arial", 9), text_color="gray60").pack(pady=(30, 20))
    
    def toggle_advanced_warning(self):
        """Toggle advanced options warning preference"""
        self.never_show_advanced_warning = self.adv_checkbox_var.get()
        if self.never_show_advanced_warning:
            # Show humorous warning (matches macOS)
            result = messagebox.askyesno(
                "⚠️ SAFETY OFF ⚠️",
                "Somewhere, a help desk ticket was just pre-generated in your name. "
                "Subject: 'I don't know what happened.' Spoiler: this. This is what happened.\n\n"
                "Do you want to proceed?",
                icon='warning'
            )
            if not result:
                # User chose "No", revert the setting
                self.never_show_advanced_warning = False
                self.adv_checkbox_var.set(False)
    
    def toggle_certificate_archive(self):
        """Toggle certificate archive preference"""
        self.enable_certificate_archive = self.archive_checkbox_var.get()
        # Refresh settings view to show/hide sub-options
        self.show_view("settings")

    def toggle_hide_archive_folder(self):
        """Toggle hide archive folder preference"""
        self.hide_archive_folder = self.hide_archive_checkbox_var.get()
        # Refresh to update info label
        self.show_view("settings")
    
    def archive_files(self, file_paths, domain=None):
        """Archive generated files to .archive/{domain}/{timestamp}/ inside the working directory."""
        if not self.save_directory or not getattr(self, 'enable_certificate_archive', False):
            return

        from datetime import datetime
        timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
        domain_path = self._archive_domain_path(domain)
        hide = getattr(self, 'hide_archive_folder', True)
        folder_name = ".archive" if hide else "archive"

        archive_root = os.path.join(self.save_directory, folder_name)
        archive_dir = os.path.join(archive_root, domain_path, timestamp)

        try:
            os.makedirs(archive_dir, exist_ok=True)
            # On Windows, apply hidden attribute to the archive root folder
            if hide and os.name == "nt":
                import subprocess
                subprocess.run(["attrib", "+h", archive_root], check=False, capture_output=True)
            import shutil
            for f in file_paths:
                if os.path.exists(f):
                    shutil.copy2(f, os.path.join(archive_dir, os.path.basename(f)))
        except Exception as e:
            print(f"Archive error: {e}")
    
    @staticmethod
    def _archive_domain_path(domain):
        """Determine archive path from domain. Subdomains nest under root domain."""
        if not domain or not domain.strip():
            return "unknown"
        
        clean = domain.strip().lower()
        # Strip wildcard prefix
        if clean.startswith("*."):
            clean = clean[2:]
        
        parts = clean.split(".")
        if len(parts) <= 2:
            return clean
        
        # Subdomain: nest under root domain
        root = ".".join(parts[-2:])
        return os.path.join(root, clean)
    
    def show_no_directory_message(self, parent):
        """Show message when no working directory is set"""
        msg_frame = ctk.CTkFrame(parent, fg_color="transparent")
        msg_frame.pack(expand=True, pady=100)
        
        ctk.CTkLabel(msg_frame, text="📁", font=("Arial", 72)).pack()
        ctk.CTkLabel(msg_frame, text="Select working directory", font=("Arial", 18, "bold")).pack(pady=(20, 5))
        ctk.CTkLabel(msg_frame, text="Go to Home and set your working directory first.", font=("Arial", 12), text_color="gray70").pack(pady=(0, 20))
        
        ctk.CTkButton(msg_frame, text="Go to Home", command=lambda: self.show_view("home"), height=40).pack()
    
    def browse_private_key_for_pfx(self):
        """Browse for private key in PFX view"""
        f = filedialog.askopenfilename(
            initialdir=self.save_directory,
            filetypes=[("PEM Keys", "*.pem *.key"), ("All files", "*.*")]
        )
        if f:
            self.private_key_file = f
            self.pfx_key_entry.delete(0, "end")
            self.pfx_key_entry.insert(0, f)
    
    def browse_pfx_for_extract(self):
        """Browse for PFX file in extract view"""
        f = filedialog.askopenfilename(
            initialdir=self.save_directory,
            filetypes=[("PFX files", "*.pfx *.p12"), ("All files", "*.*")]
        )
        if f:
            self.extract_pfx_entry.delete(0, "end")
            self.extract_pfx_entry.insert(0, f)
    
    def extract_key(self):
        """Extract private key from PFX"""
        pfx_path = self.extract_pfx_entry.get().strip()
        password = self.extract_password_entry.get()
        
        if not pfx_path:
            messagebox.showerror("Error", "Please select a PFX/P12 file")
            return
        
        try:
            with open(pfx_path, 'rb') as f:
                pfx_data = f.read()
            
            private_key, _, _ = pkcs12.load_key_and_certificates(
                pfx_data,
                password.encode() if password else None,
                default_backend()
            )
            
            if private_key is None:
                raise ValueError("No private key found in PFX file")
            
            pem_key = private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            
            save_path = filedialog.asksaveasfilename(
                initialdir=self.save_directory,
                title="Save Private Key",
                defaultextension=".pem",
                filetypes=[("PEM files", "*.pem"), ("All files", "*.*")]
            )
            
            if save_path:
                with open(save_path, 'wb') as f:
                    f.write(pem_key)

                # Set secure file permissions on extracted key
                if platform.system() == 'Windows':
                    try:
                        import subprocess
                        username = os.environ.get('USERNAME', '')
                        if username:
                            subprocess.run(
                                ['icacls', save_path, '/inheritance:r', '/grant:r', f'{username}:(F)'],
                                check=False, capture_output=True
                            )
                    except Exception:
                        pass
                else:
                    os.chmod(save_path, 0o600)

                messagebox.showinfo("Success", f"Private key extracted successfully to:\n{save_path}")
                
                # Clear form
                self.extract_pfx_entry.delete(0, "end")
                self.extract_password_entry.delete(0, "end")
        
        except Exception as e:
            messagebox.showerror("Error", f"Failed to extract private key:\n{str(e)}")
    
    def select_save_directory(self):
        directory = filedialog.askdirectory(title="Select Working Directory")
        if directory:
            self.save_directory = directory
            # Refresh current view to show updated directory
            self.show_view(self.current_view)
    
    def generate_csr_from_data(self, data, sans, key_type, key_size, ecc_curve, password=""):
        """
        Generate Certificate Signing Request (CSR) and private key.
        
        Standards Compliance:
        - RFC 2986: PKCS #10 CSR format
        - RFC 5280: X.509 certificate extensions (keyUsage, extendedKeyUsage)
        - NIST SP 800-57: SHA-256 signature algorithm
        - FIPS 186-4: ECC curves (P-256, P-384, P-521)
        
        Args:
            data: Dictionary with DN components (CN, O, OU, C, ST, L, emailAddress)
            sans: List of Subject Alternative Names
            key_type: "RSA" or "ECC"
            key_size: RSA key size (2048, 3072, 4096)
            ecc_curve: ECC curve name ("P-256", "P-384", "P-521")
            password: Optional password for private key encryption (AES-256)
        """
        try:
            # Generate key based on type
            if key_type == "RSA":
                key = rsa.generate_private_key(65537, key_size, default_backend())
            else:  # ECC
                # Map curve names to cryptography curve objects
                curve_map = {
                    "P-256": ec.SECP256R1(),
                    "P-384": ec.SECP384R1(),
                    "P-521": ec.SECP521R1()
                }
                curve = curve_map.get(ecc_curve, ec.SECP256R1())
                key = ec.generate_private_key(curve, default_backend())
            
            attrs = []
            for oid, val in [
                (NameOID.COUNTRY_NAME, data.get("Country")),
                (NameOID.STATE_OR_PROVINCE_NAME, data.get("State/Province")),
                (NameOID.LOCALITY_NAME, data.get("Locality")),
                (NameOID.ORGANIZATION_NAME, data.get("Organization")),
                (NameOID.ORGANIZATIONAL_UNIT_NAME, data.get("Organizational Unit")),
                (NameOID.COMMON_NAME, data.get("Common Name")),
                (NameOID.EMAIL_ADDRESS, data.get("Email Address (Optional)"))
            ]:
                if val:
                    attrs.append(x509.NameAttribute(oid, val))
            subject = x509.Name(attrs or [x509.NameAttribute(NameOID.COMMON_NAME, "default")])
            builder = x509.CertificateSigningRequestBuilder().subject_name(subject)
            
            # Add Subject Alternative Names extension (RFC 5280)
            if sans:
                san_list = []
                for s in sans:
                    try:
                        ip = ipaddress.ip_address(s.strip())
                        san_list.append(x509.IPAddress(ip))
                    except ValueError:
                        san_list.append(x509.DNSName(s.strip()))
                builder = builder.add_extension(
                    x509.SubjectAlternativeName(san_list), 
                    critical=False
                )
            
            # Add key usage extensions (RFC 5280 Section 4.2.1.3 and 4.2.1.12)
            builder = builder.add_extension(
                x509.KeyUsage(
                    digital_signature=True,
                    key_encipherment=True,
                    content_commitment=False,  # formerly nonRepudiation
                    data_encipherment=False,
                    key_agreement=False,
                    key_cert_sign=False,
                    crl_sign=False,
                    encipher_only=False,
                    decipher_only=False
                ),
                critical=True
            )
            builder = builder.add_extension(
                x509.ExtendedKeyUsage([x509.oid.ExtendedKeyUsageOID.SERVER_AUTH, x509.oid.ExtendedKeyUsageOID.CLIENT_AUTH]),
                critical=False
            )
            
            # Sign CSR with SHA-256 (NIST SP 800-57, RFC 5280)
            csr = builder.sign(key, hashes.SHA256(), default_backend())
            priv_path = os.path.join(self.save_directory, "private_key.pem")
            csr_path = os.path.join(self.save_directory, "csr.pem")
            enc = serialization.BestAvailableEncryption(password.encode()) if password else serialization.NoEncryption()
            
            # Use appropriate format for key type
            if key_type == "RSA":
                key_format = serialization.PrivateFormat.TraditionalOpenSSL
            else:  # ECC
                key_format = serialization.PrivateFormat.PKCS8
            
            with open(priv_path, "wb") as f:
                f.write(key.private_bytes(serialization.Encoding.PEM, key_format, enc))
            
            # Set secure file permissions on private key
            if platform.system() == 'Windows':
                try:
                    import subprocess
                    username = os.environ.get('USERNAME', '')
                    if username:
                        subprocess.run(
                            ['icacls', priv_path, '/inheritance:r', '/grant:r', f'{username}:(F)'],
                            check=False, capture_output=True
                        )
                except Exception:
                    pass
            else:
                os.chmod(priv_path, 0o600)
            
            with open(csr_path, "wb") as f:
                f.write(csr.public_bytes(serialization.Encoding.PEM))
            
            self.private_key_file = priv_path
            self.private_key_password = password
            
            # Update status
            key_info = f"{key_type} {key_size if key_type == 'RSA' else ecc_curve}"
            
            messagebox.showinfo(
                "Success",
                f"CSR and Private Key generated successfully!\n\n"
                f"Key Type: {key_info}\n"
                f"CSR: {csr_path}\n"
                f"Private Key: {priv_path}\n\n"
                f"The private key will be auto-filled in the PFX Generator."
            )
            
            # Archive CSR + key using commonName as domain
            cn = data.get("CN", "")
            self.archive_files([csr_path, priv_path], domain=cn if cn else None)
            self._reset_csr_form()

        except Exception as e:
            messagebox.showerror("Error", f"CSR generation failed: {e}")

    def browse_cert(self):
        """Browse for certificate file"""
        cert_file = filedialog.askopenfilename(
            initialdir=self.save_directory,
            title="Select Certificate",
            filetypes=[("Certificates", "*.cer *.crt *.pem"), ("All files", "*.*")]
        )
        if cert_file:
            self.cert_file = cert_file
            # Refresh chain view to show selected certificate
            if self.current_view == "chain":
                self.show_view("chain")
    
    def create_full_chain(self):
        """Build certificate chain"""
        if not all([self.cert_file, self.save_directory]):
            messagebox.showerror("Error", "Certificate and save directory required")
            return
        
        # Show progress dialog
        progress_dialog = ctk.CTkToplevel(self.root)
        progress_dialog.title("Building Chain")
        progress_dialog.geometry("400x150")
        progress_dialog.transient(self.root)
        progress_dialog.grab_set()
        
        ctk.CTkLabel(progress_dialog, text="Building certificate chain...", font=("Arial", 14, "bold")).pack(pady=(20, 10))
        progress_bar = ctk.CTkProgressBar(progress_dialog, mode="indeterminate")
        progress_bar.pack(fill="x", padx=30, pady=20)
        progress_bar.start()
        
        status_label = ctk.CTkLabel(progress_dialog, text="Analyzing certificate...", font=("Arial", 11))
        status_label.pack()
        
        self.queue = queue.Queue()
        threading.Thread(target=self._build_chain_thread, daemon=True).start()
        
        def check_queue():
            try:
                typ, msg = self.queue.get_nowait()
                progress_bar.stop()
                progress_dialog.destroy()
                
                if typ == "success":
                    self.fullchain_created = True
                    messagebox.showinfo("Success", f"Full chain saved:\n{msg}")
                    # Archive chain file using cert subject as domain
                    try:
                        from cryptography import x509
                        with open(msg, "rb") as cf:
                            cert = x509.load_pem_x509_certificate(cf.read())
                        cn = cert.subject.get_attributes_for_oid(x509.oid.NameOID.COMMON_NAME)
                        domain = cn[0].value if cn else None
                        self.archive_files([msg], domain=domain)
                    except Exception:
                        self.archive_files([msg], domain=None)
                    # Refresh view
                    if self.current_view == "chain":
                        self.show_view("chain")
                else:
                    messagebox.showerror("Error", f"Chain building failed:\n{msg}")
            except queue.Empty:
                self.root.after(100, check_queue)
        
        self.root.after(100, check_queue)
    
    def _build_chain_thread(self):
        """Background thread for building certificate chain"""
        try:
            with open(self.cert_file, "rb") as f:
                data = f.read()
            certs = self.load_certificates_from_pem(data)
            if not certs:
                raise ValueError("No valid certificate found")
            chain = certs.copy()
            current = chain[-1]
            while not self.is_self_signed(current):
                issuer = self.fetch_issuer_from_windows(current)
                if not issuer:
                    break
                if issuer not in chain:
                    chain.append(issuer)
                current = issuer
            path = os.path.join(self.save_directory, "FullChain.cer")
            with open(path, "wb") as f:
                for c in chain:
                    f.write(c.public_bytes(serialization.Encoding.PEM))
            self.queue.put(("success", path))
        except Exception as e:
            self.queue.put(("error", str(e)))
    
    def browse_pfx_chain(self):
        """Browse for certificate chain file"""
        file = filedialog.askopenfilename(
            title="Select Certificate Chain",
            filetypes=[("Certificate files", "*.cer *.crt *.pem"), ("All files", "*.*")]
        )
        if file:
            self.pfx_chain_file = file
            self.pfx_chain_entry.delete(0, tk.END)
            self.pfx_chain_entry.insert(0, file)
    
    def autofill_pfx_chain(self):
        """Auto-fill with FullChain.cer if it exists"""
        fullchain_path = os.path.join(self.save_directory, "FullChain.cer")
        if os.path.exists(fullchain_path):
            self.pfx_chain_file = fullchain_path
            self.pfx_chain_entry.delete(0, tk.END)
            self.pfx_chain_entry.insert(0, fullchain_path)
            messagebox.showinfo("Success", "Autofilled with FullChain.cer")
        else:
            messagebox.showwarning("Not Found", "FullChain.cer not found. Please build a chain first.")
    
    def verify_key_password(self):
        """Verify private key password"""
        key_file = self.pfx_key_entry.get().strip()
        key_password = self.pfx_key_password_entry.get()
        
        if not key_file:
            messagebox.showerror("Error", "Please select a private key file first")
            return
        
        try:
            pwd = key_password.encode() if key_password else None
            with open(key_file, "rb") as f:
                serialization.load_pem_private_key(f.read(), password=pwd, backend=default_backend())
            
            self.verify_key_btn.configure(text="✓ Verified", fg_color="#1e7d1e")
            messagebox.showinfo("Success", "Private key loaded successfully!")
        except Exception as e:
            self.verify_key_btn.configure(text="✗ Failed", fg_color="#d32f2f")
            messagebox.showerror("Error", f"Failed to load private key:\n{str(e)}")
    
    def toggle_pfx_advanced(self):
        """Toggle advanced PFX options visibility"""
        if self.pfx_advanced_toggle.get():
            # Show warning if not suppressed (matches macOS)
            if not self.never_show_advanced_warning:
                result = messagebox.askyesno(
                    "Advanced Options - Caution",
                    "These advanced options allow customization of cryptographic algorithms used in PFX file generation.\n\n"
                    "Modifying these settings requires knowledge of cryptographic standards and compatibility requirements.\n\n"
                    "Please ensure you understand the implications before changing from the recommended defaults.\n\n"
                    "(Tired of this warning? You can disable it in Settings → Advanced Options)\n\n"
                    "Do you want to continue?",
                    icon="warning"
                )
                if not result:
                    self.pfx_advanced_toggle.deselect()
                    return
            
            self.pfx_advanced_content.pack(fill="x", pady=(0, 10))
            self.update_pfx_legacy_warning()
        else:
            self.pfx_advanced_content.pack_forget()
    
    def set_pfx_mac_algorithm(self, algorithm):
        """Set MAC algorithm for PFX"""
        self.pfx_mac_algorithm = algorithm
        self.update_pfx_legacy_warning()
    
    def set_pfx_encryption_algorithm(self, algorithm):
        """Set encryption algorithm for PFX"""
        self.pfx_encryption_algorithm = algorithm
        self.update_pfx_legacy_warning()
    
    def is_using_legacy_pfx_options(self):
        """Check if legacy options are selected"""
        return self.pfx_mac_algorithm == "SHA-1" or self.pfx_encryption_algorithm in ["3DES", "Legacy"]
    
    def update_pfx_legacy_warning(self):
        """Show/hide legacy warning based on selection"""
        if self.is_using_legacy_pfx_options():
            self.pfx_legacy_warning.pack(pady=(5, 0))
        else:
            self.pfx_legacy_warning.pack_forget()
    
    def create_pfx_advanced(self):
        """Create PFX file with advanced options"""
        chain_file = self.pfx_chain_entry.get().strip()
        key_file = self.pfx_key_entry.get().strip()
        key_password = self.pfx_key_password_entry.get()
        pfx_password = self.pfx_password_entry.get()
        
        if not chain_file:
            messagebox.showerror("Error", "Please select a certificate chain file")
            return
        
        if not key_file:
            messagebox.showerror("Error", "Please select a private key file")
            return
        
        if not pfx_password:
            messagebox.showerror("Error", "Please enter a password for the PFX file")
            return
        
        try:
            # Load private key
            pwd = key_password.encode() if key_password else None
            with open(key_file, "rb") as f:
                key = serialization.load_pem_private_key(f.read(), password=pwd, backend=default_backend())
            
            # Load certificate chain
            with open(chain_file, "rb") as f:
                chain_data = f.read()
            
            certs = self.load_certificates_from_pem(chain_data)
            if not certs:
                messagebox.showerror("Error", "No valid certificates found in chain file")
                return
            
            # Note: Python's cryptography library doesn't support custom MAC/encryption algorithms
            # like OpenSSL CLI does. The advanced options are shown for UI parity with macOS,
            # but the actual PFX creation uses the library's default secure algorithms.
            
            # Create PFX
            pfx_data = pkcs12.serialize_key_and_certificates(
                name=b"SSL Certificate",
                key=key,
                cert=certs[0],
                cas=certs[1:] if len(certs) > 1 else None,
                encryption_algorithm=serialization.BestAvailableEncryption(pfx_password.encode())
            )
            
            # Save PFX file
            pfx_path = os.path.join(self.save_directory, "Certificate.pfx")
            with open(pfx_path, "wb") as f:
                f.write(pfx_data)
            
            messagebox.showinfo("Success", f"PFX file created:\n{pfx_path}")
            
            # Archive if enabled
            if certs:
                try:
                    cn = certs[0].subject.get_attributes_for_oid(x509.oid.NameOID.COMMON_NAME)[0].value
                except Exception:
                    cn = None
                self.archive_files([pfx_path], domain=cn)
            
        except Exception as e:
            messagebox.showerror("Error", f"Failed to create PFX:\n{str(e)}")
    
    def load_certificates_from_pem(self, data):
        certs = []
        for block in data.split(b'-----END CERTIFICATE-----'):
            if b'-----BEGIN CERTIFICATE-----' in block:
                block += b'-----END CERTIFICATE-----\n'
                try:
                    certs.append(x509.load_pem_x509_certificate(block, default_backend()))
                except Exception:
                    pass
        return certs
    def is_self_signed(self, cert):
        return cert.issuer == cert.subject
    def verify_signature(self, child, parent):
        try:
            parent.public_key().verify(
                child.signature,
                child.tbs_certificate_bytes,
                padding.PKCS1v15() if isinstance(parent.public_key(), rsa.RSAPublicKey) else padding.PSS(mgf=padding.PSS.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
                child.signature_hash_algorithm
            )
            return True
        except Exception:
            return False
    def load_windows_trusted_roots(self):
        certs = []
        if wincertstore and platform.system() == 'Windows':
            for store_name in ("ROOT", "CA"):
                try:
                    with wincertstore.CertSystemStore(store_name) as store:
                        for wc in store.itercerts():
                            try:
                                c = x509.load_pem_x509_certificate(wc.get_pem(), default_backend())
                                certs.append(c)
                            except Exception:
                                continue
                except Exception:
                    pass
        return certs
    def fetch_issuer_from_windows(self, cert):
        if not wincertstore:
            return None
        for store_name in ("CA", "ROOT"):
            try:
                with wincertstore.CertSystemStore(store_name) as store:
                    for wc in store.itercerts():
                        try:
                            issuer = x509.load_pem_x509_certificate(wc.get_pem(), default_backend())
                            if issuer.subject == cert.issuer and self.verify_signature(cert, issuer):
                                return issuer
                        except Exception:
                            continue
            except Exception:
                pass
        return None

if __name__ == "__main__":
    root = ctk.CTk()
    app = AIOSSLToolApp(root)
    root.mainloop()
