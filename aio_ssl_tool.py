import os
import sys
import customtkinter as ctk
from tkinter import filedialog, messagebox, Menu, Toplevel, simpledialog
from cryptography import x509
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
import requests
import platform
import threading
import queue

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

class CSRDialog(ctk.CTkToplevel):
    def __init__(self, parent, callback):
        super().__init__(parent)
        self.callback = callback
        self.title("Generate CSR and Private Key")
        self.resizable(True, True)
        self.transient(parent)
        self.grab_set()
        self.geometry("720x700")
        main_container = ctk.CTkFrame(self)
        main_container.pack(fill="both", expand=True)
        self.canvas = ctk.CTkCanvas(main_container)
        self.scrollbar = ctk.CTkScrollbar(main_container, orientation="vertical", command=self.canvas.yview)
        self.scrollable_frame = ctk.CTkFrame(self.canvas)
        self.scrollable_frame.bind("<Configure>", lambda e: self._update_scroll())
        self.canvas.create_window((0, 0), window=self.scrollable_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.bind("<Configure>", self._update_scrollbar)
        self.canvas.pack(side="left", fill="both", expand=True)
        content = ctk.CTkFrame(self.scrollable_frame, corner_radius=12, fg_color="transparent")
        content.pack(pady=20, padx=25, fill="both", expand=True)
        ctk.CTkLabel(content, text="CSR Details", font=("Arial", 18, "bold")).pack(pady=(0, 15))
        fields = [
            ("Common Name (CN)", "example.com"),
            ("Country (C)", "US"),
            ("State/Province (ST)", "California"),
            ("Locality (L)", "San Francisco"),
            ("Organization (O)", "My Company"),
            ("Organizational Unit (OU)", "IT Department"),
            ("Email Address", "admin@example.com")
        ]
        self.entries = {}
        for label_text, placeholder in fields:
            row = ctk.CTkFrame(content)
            row.pack(fill="x", pady=4)
            ctk.CTkLabel(row, text=label_text + ":", width=160, anchor="w").pack(side="left")
            entry = ctk.CTkEntry(row, placeholder_text=placeholder, height=36)
            entry.pack(side="right", fill="x", expand=True, padx=(10, 0))
            self.entries[label_text.split(" (")[0]] = entry
        ctk.CTkLabel(content, text="SANs (one per line):", anchor="w").pack(fill="x", pady=(15, 5))
        self.san_text = ctk.CTkTextbox(content, height=120, wrap="none")
        self.san_text.pack(fill="both", expand=True, pady=(0, 10))
        self.placeholder_text = "www.example.com\nmail.example.com\nautodiscover.example.com"
        self.san_text.insert("1.0", self.placeholder_text)
        self.san_text.tag_add("placeholder", "1.0", "end")
        self.san_text.tag_config("placeholder", foreground="#888888")
        self.placeholder_active = True
        options_frame = ctk.CTkFrame(content)
        options_frame.pack(fill="x", pady=10)
        ctk.CTkLabel(options_frame, text="Key Size:", width=160, anchor="w").pack(side="left", padx=(0, 10))
        self.key_size_var = ctk.StringVar(value="2048")
        ctk.CTkComboBox(options_frame, values=["2048", "3072", "4096"], variable=self.key_size_var, width=120).pack(side="left")
        ctk.CTkLabel(options_frame, text=" Passphrase (optional):", anchor="w").pack(side="left", padx=(20, 5))
        self.private_key_pass_entry = ctk.CTkEntry(options_frame, show="*", placeholder_text="Leave blank = no password", width=200)
        self.private_key_pass_entry.pack(side="right")
        btn_frame = ctk.CTkFrame(content, fg_color="transparent")
        btn_frame.pack(fill="x", pady=20)
        ctk.CTkButton(btn_frame, text="Generate CSR + Key", command=self.on_generate,
                      font=("Arial", 12, "bold"), height=40, fg_color="#1e7d1e", hover_color="#1a6b1a").pack(
            side="left", padx=10, expand=True, fill="x")
        ctk.CTkButton(btn_frame, text="Cancel", command=self.destroy,
                      font=("Arial", 12), height=40, fg_color="#7d1e1e", hover_color="#6b1a1a").pack(
            side="right", padx=10, expand=True, fill="x")
        self.san_text.bind("<FocusIn>", self.on_san_focus_in)
        self.san_text.bind("<FocusOut>", self.on_san_focus_out)
    def _update_scroll(self):
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        self._update_scrollbar()
    def _update_scrollbar(self, event=None):
        canvas_height = self.canvas.winfo_height()
        scrollregion = self.canvas.cget("scrollregion")
        if scrollregion:
            coords = scrollregion.split()
            if len(coords) == 4:
                content_height = int(coords[3])
                needs_scroll = content_height > canvas_height
                if needs_scroll and not self.scrollbar.winfo_ismapped():
                    self.scrollbar.pack(side="right", fill="y")
                elif not needs_scroll and self.scrollbar.winfo_ismapped():
                    self.scrollbar.pack_forget()
    def on_san_focus_in(self, event):
        if self.placeholder_active:
            self.san_text.delete("1.0", "end")
            self.san_text.tag_remove("placeholder", "1.0", "end")
            self.placeholder_active = False
    def on_san_focus_out(self, event):
        if not self.san_text.get("1.0", "end-1c").strip():
            self.san_text.insert("1.0", self.placeholder_text)
            self.san_text.tag_add("placeholder", "1.0", "end")
            self.placeholder_active = True
    def on_generate(self):
        data = {k: e.get().strip() for k, e in self.entries.items()}
        raw_san = self.san_text.get("1.0", "end-1c").strip()
        sans = [line.strip() for line in raw_san.splitlines() if line.strip() and not self.placeholder_active]
        try:
            key_size = int(self.key_size_var.get())
        except:
            messagebox.showerror("Error", "Invalid key size")
            return
        password = self.private_key_pass_entry.get().strip()
        self.callback(data, sans, key_size, password)
        self.destroy()

class ExtractPFXDialog(ctk.CTkToplevel):
    def __init__(self, parent, callback):
        super().__init__(parent)
        self.callback = callback
        self.title("Extract Private Key from PFX/P12")
        self.resizable(True, True)
        self.transient(parent)
        self.grab_set()
        self.geometry("440x215")
        main_container = ctk.CTkFrame(self)
        main_container.pack(fill="both", expand=True)
        self.canvas = ctk.CTkCanvas(main_container)
        self.scrollbar = ctk.CTkScrollbar(main_container, orientation="vertical", command=self.canvas.yview)
        self.scrollable_frame = ctk.CTkFrame(self.canvas)
        self.scrollable_frame.bind("<Configure>", lambda e: self._update_scroll())
        self.canvas.create_window((0, 0), window=self.scrollable_frame, anchor="nw")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.bind("<Configure>", self._update_scrollbar)
        self.canvas.pack(side="left", fill="both", expand=True)
        content = ctk.CTkFrame(self.scrollable_frame, corner_radius=12, fg_color="transparent")
        content.pack(pady=0, padx=0, fill="both", expand=True)
        ctk.CTkLabel(content, text="Extract Private Key", font=("Arial", 18, "bold")).pack(pady=(0, 15))
        file_row = ctk.CTkFrame(content)
        file_row.pack(fill="x", pady=4)
        ctk.CTkLabel(file_row, text="PFX/P12 File:", width=160, anchor="w").pack(side="left")
        self.pfx_entry = ctk.CTkEntry(file_row, placeholder_text="Select file...", height=36)
        self.pfx_entry.pack(side="left", fill="x", expand=True, padx=(10, 10))
        browse_btn = ctk.CTkButton(file_row, text="Browse", command=self.browse_pfx, width=100)
        browse_btn.pack(side="right")
        pass_row = ctk.CTkFrame(content)
        pass_row.pack(fill="x", pady=4)
        ctk.CTkLabel(pass_row, text="Passphrase:", width=160, anchor="w").pack(side="left")
        self.pass_entry = ctk.CTkEntry(pass_row, show="*", placeholder_text="Enter passphrase...", height=36)
        self.pass_entry.pack(side="right", fill="x", expand=True, padx=(10, 0))
        btn_frame = ctk.CTkFrame(content, fg_color="transparent")
        btn_frame.pack(fill="x", pady=20)
        ctk.CTkButton(btn_frame, text="Extract Key", command=self.on_extract,
                      font=("Arial", 12, "bold"), height=40, fg_color="#1e7d1e", hover_color="#1a6b1a").pack(
            side="left", padx=10, expand=True, fill="x")
        ctk.CTkButton(btn_frame, text="Cancel", command=self.destroy,
                      font=("Arial", 12), height=40, fg_color="#7d1e1e", hover_color="#6b1a1a").pack(
            side="right", padx=10, expand=True, fill="x")
    def _update_scroll(self):
        self.canvas.configure(scrollregion=self.canvas.bbox("all"))
        self._update_scrollbar()
    def _update_scrollbar(self, event=None):
        canvas_height = self.canvas.winfo_height()
        scrollregion = self.canvas.cget("scrollregion")
        if scrollregion:
            coords = scrollregion.split()
            if len(coords) == 4:
                content_height = int(coords[3])
                needs_scroll = content_height > canvas_height
                if needs_scroll and not self.scrollbar.winfo_ismapped():
                    self.scrollbar.pack(side="right", fill="y")
                elif not needs_scroll and self.scrollbar.winfo_ismapped():
                    self.scrollbar.pack_forget()
    def browse_pfx(self):
        path = filedialog.askopenfilename(filetypes=[("PFX files", "*.pfx *.p12")])
        if path:
            self.pfx_entry.delete(0, "end")
            self.pfx_entry.insert(0, path)
    def on_extract(self):
        pfx_path = self.pfx_entry.get().strip()
        pass_phrase = self.pass_entry.get()
        if not pfx_path:
            messagebox.showerror("Error", "Please select a PFX/P12 file")
            return
        self.callback(pfx_path, pass_phrase)
        self.destroy()

class AIOSSLToolApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CMDLAB AIO SSL Tool")
        self.root.geometry("540x620")
        self.root.resizable(True, True)
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("dark-blue")
        try:
            self.root.iconbitmap(resource_path("icon-ico.ico"))
        except:
            pass
        self.cert_file = None
        self.save_directory = None
        self.private_key_file = None
        self.root_certs = self.load_windows_trusted_roots()
        self.create_menu()
        self.create_widgets()
    def create_menu(self):
        menu = Menu(self.root)
        self.root.config(menu=menu)
        file_menu = Menu(menu, tearoff=0)
        file_menu.add_command(label="Generate CSR and Private Key", command=self.open_csr_dialog)
        file_menu.add_command(label="Extract Private Key from PFX/P12", command=self.open_extract_dialog)
        menu.add_cascade(label="File", menu=file_menu)
        about_menu = Menu(menu, tearoff=0)
        about_menu.add_command(label="Version: v5.6", state="disabled")
        menu.add_cascade(label="About", menu=about_menu)
    def open_csr_dialog(self):
        if not self.save_directory:
            messagebox.showwarning("Warning", "Please select save location first")
            return
        CSRDialog(self.root, self.generate_csr_from_data)
    def open_extract_dialog(self):
        if not self.save_directory:
            messagebox.showwarning("Warning", "Please select save location first")
            return
        ExtractPFXDialog(self.root, self.extract_private_key_callback)
    def generate_csr_from_data(self, data, sans, key_size, password=""):
        try:
            key = rsa.generate_private_key(65537, key_size, default_backend())
            attrs = []
            for oid, val in [
                (NameOID.COUNTRY_NAME, data.get("Country")),
                (NameOID.STATE_OR_PROVINCE_NAME, data.get("State/Province")),
                (NameOID.LOCALITY_NAME, data.get("Locality")),
                (NameOID.ORGANIZATION_NAME, data.get("Organization")),
                (NameOID.ORGANIZATIONAL_UNIT_NAME, data.get("Organizational Unit")),
                (NameOID.COMMON_NAME, data.get("Common Name")),
                (NameOID.EMAIL_ADDRESS, data.get("Email Address"))
            ]:
                if val:
                    attrs.append(x509.NameAttribute(oid, val))
            subject = x509.Name(attrs or [x509.NameAttribute(NameOID.COMMON_NAME, "default")])
            builder = x509.CertificateSigningRequestBuilder().subject_name(subject)
            if sans:
                builder = builder.add_extension(x509.SubjectAlternativeName([x509.DNSName(s) for s in sans]), critical=False)
            csr = builder.sign(key, hashes.SHA256(), default_backend())
            priv_path = os.path.join(self.save_directory, "private_key.pem")
            csr_path = os.path.join(self.save_directory, "csr.pem")
            enc = serialization.BestAvailableEncryption(password.encode()) if password else serialization.NoEncryption()
            with open(priv_path, "wb") as f:
                f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL, enc))
            with open(csr_path, "wb") as f:
                f.write(csr.public_bytes(serialization.Encoding.PEM))
            self.private_key_file = priv_path
            self.private_key_password_entry.delete(0, "end")
            self.private_key_password_entry.insert(0, password)
            self.private_key_button.configure(text="4. Private Key - Generated")
            self.chain_status_label.configure(text="CSR + Key generated")
            if os.path.exists(os.path.join(self.save_directory, "FullChain.cer")):
                self.create_pfx_button.configure(state="normal")
        except Exception as e:
            messagebox.showerror("Error", f"CSR generation failed: {e}")
    def extract_private_key_callback(self, pfx_path, pass_phrase):
        try:
            with open(pfx_path, 'rb') as f:
                pfx_data = f.read()
            private_key, _, _ = pkcs12.load_key_and_certificates(pfx_data, pass_phrase.encode(), default_backend())
            if private_key is None:
                raise ValueError("No private key found.")
            pem_key = private_key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.PKCS8,
                encryption_algorithm=serialization.NoEncryption()
            )
            save_path = filedialog.asksaveasfilename(initialdir=self.save_directory, title="Save Private Key", defaultextension=".pem", filetypes=[("PEM files", "*.pem")])
            if save_path:
                with open(save_path, 'wb') as f:
                    f.write(pem_key)
                messagebox.showinfo("Success", "Private key extracted successfully.")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to extract private key: {str(e)}")
    def create_widgets(self):
        frame = ctk.CTkFrame(self.root, corner_radius=10)
        frame.pack(pady=10, padx=10, fill="both", expand=True)
        ctk.CTkLabel(frame, text="CMDLAB AIO SSL Tool", font=("Arial", 18, "bold")).pack(pady=(10, 20))
        ctk.CTkLabel(frame, text="Build full chains and PFX from any certificate", font=("Arial", 10)).pack(pady=(0, 15))
        self.save_dir_button = ctk.CTkButton(frame, text="1. Select Save Location", command=self.select_save_directory)
        self.save_dir_button.pack(fill="x", pady=8, padx=20)
        self.browse_button = ctk.CTkButton(frame, text="2. Browse Certificate", command=self.browse_cert, state="disabled")
        self.browse_button.pack(fill="x", pady=8, padx=20)
        self.fullchain_button = ctk.CTkButton(frame, text="3. Create Full Chain", command=self.create_full_chain, state="disabled")
        self.fullchain_button.pack(fill="x", pady=12, padx=20)
        self.private_key_button = ctk.CTkButton(frame, text="4. Browse Private Key", command=self.browse_private_key, state="disabled")
        self.private_key_button.pack(fill="x", pady=8, padx=20)
        kframe = ctk.CTkFrame(frame, fg_color="transparent")
        kframe.pack(fill="x", pady=5, padx=20)
        ctk.CTkLabel(kframe, text="Key Passphrase:").pack(side="left", padx=5)
        self.private_key_password_entry = ctk.CTkEntry(kframe, show="*", width=200)
        self.private_key_password_entry.pack(side="left", fill="x", expand=True)
        pframe = ctk.CTkFrame(frame, fg_color="transparent")
        pframe.pack(fill="x", pady=5, padx=20)
        ctk.CTkLabel(pframe, text="PFX Passphrase:").pack(side="left", padx=5)
        self.pfx_password_entry = ctk.CTkEntry(pframe, show="*", width=200)
        self.pfx_password_entry.pack(side="left", fill="x", expand=True)
        self.create_pfx_button = ctk.CTkButton(frame, text="5. Create PFX", command=self.create_pfx, state="disabled")
        self.create_pfx_button.pack(fill="x", pady=12, padx=20)
        self.chain_status_label = ctk.CTkLabel(frame, text="Ready", font=("Arial", 10, "italic"))
        self.chain_status_label.pack(pady=10)
        self.progress = ctk.CTkProgressBar(frame, mode="indeterminate")
        self.progress.pack(fill="x", pady=5, padx=20)
    def select_save_directory(self):
        self.save_directory = filedialog.askdirectory()
        if self.save_directory:
            self.chain_status_label.configure(text="Save location set")
            self.browse_button.configure(state="normal")
    def browse_cert(self):
        self.cert_file = filedialog.askopenfilename(filetypes=[("Certificates", "*.cer *.crt *.pem"), ("All files", "*.*")])
        if self.cert_file:
            self.fullchain_button.configure(state="normal")
            self.private_key_button.configure(state="normal")
            self.chain_status_label.configure(text="Certificate loaded")
    def create_full_chain(self):
        if not all([self.cert_file, self.save_directory]):
            return
        self.fullchain_button.configure(state="disabled")
        self.chain_status_label.configure(text="Building chain...")
        self.progress.start()
        self.queue = queue.Queue()
        threading.Thread(target=self._build_chain_thread, daemon=True).start()
        self.root.after(100, self._check_queue)
    def _build_chain_thread(self):
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
    def _check_queue(self):
        try:
            typ, msg = self.queue.get_nowait()
            self.progress.stop()
            self.fullchain_button.configure(state="normal")
            if typ == "success":
                self.chain_status_label.configure(text=f"Full chain saved: {os.path.basename(msg)}")
                self.create_pfx_button.configure(state="normal" if self.private_key_file else "disabled")
            else:
                messagebox.showerror("Error", msg)
        except queue.Empty:
            self.root.after(100, self._check_queue)
    def browse_private_key(self):
        f = filedialog.askopenfilename(filetypes=[("PEM Keys", "*.pem *.key"), ("All files", "*.*")])
        if f:
            self.private_key_file = f
            self.private_key_password_entry.delete(0, "end")
            self.chain_status_label.configure(text="Private key selected")
            if os.path.exists(os.path.join(self.save_directory, "FullChain.cer")):
                self.create_pfx_button.configure(state="normal")
    def create_pfx(self):
        if not all([self.private_key_file, self.pfx_password_entry.get(), self.save_directory]):
            messagebox.showwarning("Missing", "Need key, PFX password, and FullChain.cer")
            return
        try:
            pwd = self.private_key_password_entry.get().encode() or None
            with open(self.private_key_file, "rb") as f:
                key = serialization.load_pem_private_key(f.read(), password=pwd, backend=default_backend())
            with open(os.path.join(self.save_directory, "FullChain.cer"), "rb") as f:
                chain_data = f.read()
            certs = self.load_certificates_from_pem(chain_data)
            leaf, intermediates = certs[0], certs[1:]
            pfx = pkcs12.serialize_key_and_certificates(
                name=b"certificate",
                key=key,
                cert=leaf,
                cas=intermediates or None,
                encryption_algorithm=serialization.BestAvailableEncryption(self.pfx_password_entry.get().encode())
            )
            path = os.path.join(self.save_directory, "FullChain-pfx.pfx")
            with open(path, "wb") as f:
                f.write(pfx)
            self.chain_status_label.configure(text=f"PFX created: {os.path.basename(path)}")
        except Exception as e:
            messagebox.showerror("Error", f"PFX creation failed: {e}")
    def load_certificates_from_pem(self, data):
        certs = []
        for block in data.split(b'-----END CERTIFICATE-----'):
            if b'-----BEGIN CERTIFICATE-----' in block:
                block += b'-----END CERTIFICATE-----\n'
                try:
                    certs.append(x509.load_pem_x509_certificate(block, default_backend()))
                except:
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
        except:
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
                            except:
                                continue
                except:
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
                        except:
                            continue
            except:
                pass
        return None

if __name__ == "__main__":
    root = ctk.CTk()
    app = AIOSSLToolApp(root)
    root.mainloop()