import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import threading
import subprocess

class HEICConverterApp:
    def __init__(self, root):
        self.root = root
        self.root.title("HEIC to JPG Converter")
        self.root.geometry("500x350")
        
        # 스타일 설정
        style = ttk.Style()
        style.configure("TButton", padding=6, relief="flat", background="#ccc")
        
        # 메인 프레임
        main_frame = ttk.Frame(root, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)

        # 타이틀 라벨
        title_label = ttk.Label(main_frame, text="HEIC 이미지를 JPG로 변환", font=("Helvetica", 16, "bold"))
        title_label.pack(pady=(0, 20))

        # 파일 선택 버튼
        self.btn_select_files = ttk.Button(main_frame, text="파일 선택 (여러개 가능)", command=self.select_files)
        self.btn_select_files.pack(fill=tk.X, pady=5)
        
        # 폴더 선택 버튼
        self.btn_select_folder = ttk.Button(main_frame, text="폴더 선택 (HEIC 일괄 변환)", command=self.select_folder)
        self.btn_select_folder.pack(fill=tk.X, pady=5)

        # 선택된 경로 표시 리스트박스
        self.listbox_files = tk.Listbox(main_frame, height=6, selectmode=tk.EXTENDED)
        self.listbox_files.pack(fill=tk.BOTH, expand=True, pady=10)
        
        # 상태 표시줄 및 진행바
        self.status_var = tk.StringVar(value="준비")
        self.status_label = ttk.Label(main_frame, textvariable=self.status_var, font=("Helvetica", 10))
        self.status_label.pack(anchor=tk.W)
        
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(main_frame, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill=tk.X, pady=5)

        # 변환 시작 버튼
        self.btn_convert = ttk.Button(main_frame, text="변환 시작", command=self.start_conversion)
        self.btn_convert.pack(fill=tk.X, pady=10)

        self.selected_files = []

    def select_files(self):
        filetypes = (("HEIC files", "*.heic"), ("HEIF files", "*.heif"), ("All files", "*.*"))
        files = filedialog.askopenfilenames(title="HEIC 파일 선택", filetypes=filetypes)
        if files:
            self.add_files_to_list(files)

    def select_folder(self):
        folder = filedialog.askdirectory(title="HEIC 파일이 있는 폴더 선택")
        if folder:
            files = []
            for root, dirs, filenames in os.walk(folder):
                for filename in filenames:
                    if filename.lower().endswith(('.heic', '.heif')):
                        files.append(os.path.join(root, filename))
            
            if not files:
                messagebox.showinfo("알림", "선택한 폴더에 HEIC 파일이 없습니다.")
                return
            
            self.add_files_to_list(files)

    def add_files_to_list(self, files):
        # 중복 방지
        current_files = set(self.selected_files)
        new_files = [f for f in files if f not in current_files]
        
        if not new_files:
            return

        self.selected_files.extend(new_files)
        for f in new_files:
            self.listbox_files.insert(tk.END, f)
            
        self.status_var.set(f"총 {len(self.selected_files)}개 파일 대기 중")

    def start_conversion(self):
        if not self.selected_files:
            messagebox.showwarning("경고", "변환할 파일을 먼저 선택해주세요.")
            return

        self.btn_convert.config(state=tk.DISABLED)
        self.btn_select_files.config(state=tk.DISABLED)
        self.btn_select_folder.config(state=tk.DISABLED)
        
        # 별도 스레드에서 변환 실행 (GUI 멈춤 방지)
        threading.Thread(target=self.convert_process, daemon=True).start()

    def convert_process(self):
        total = len(self.selected_files)
        success_count = 0
        error_count = 0

        for idx, file_path in enumerate(self.selected_files):
            try:
                self.status_var.set(f"변환 중 ({idx+1}/{total}): {os.path.basename(file_path)}")
                
                # 파일 경로 분리 및 JPG 경로 생성
                directory, filename = os.path.split(file_path)
                name, ext = os.path.splitext(filename)
                new_filename = f"{name}.jpg"
                save_path = os.path.join(directory, new_filename)

                # sips 명령어 사용 (macOS 내장)
                # sips -s format jpeg input.heic --out output.jpg
                cmd = ["sips", "-s", "format", "jpeg", file_path, "--out", save_path]
                
                # 명령어 실행, 출력 숨김
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    success_count += 1
                else:
                    print(f"Error converting {file_path}: {result.stderr}")
                    error_count += 1
            except Exception as e:
                print(f"Error converting {file_path}: {e}")
                error_count += 1
            
            # 진행률 업데이트
            progress = ((idx + 1) / total) * 100
            self.progress_var.set(progress)
            self.root.update_idletasks()

        self.status_var.set(f"완료! 성공: {success_count}, 실패: {error_count}")
        messagebox.showinfo("완료", f"변환이 완료되었습니다.\n성공: {success_count}\n실패: {error_count}")
        
        # UI 초기화
        self.selected_files = []
        self.listbox_files.delete(0, tk.END)
        self.progress_var.set(0)
        self.btn_convert.config(state=tk.NORMAL)
        self.btn_select_files.config(state=tk.NORMAL)
        self.btn_select_folder.config(state=tk.NORMAL)

if __name__ == "__main__":
    root = tk.Tk()
    app = HEICConverterApp(root)
    root.mainloop()
