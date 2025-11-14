import cv2
import mediapipe as mp
import time
import math
import json  # << JSON 라이브러리 추가
from datetime import datetime  # << 시간 기록을 위한 라이브러리 추가
import requests  # 👈 1. 통신 장비(requests) 불러오기



BASE_URL = "https://onnoon.onrender.com"  # 예시 주소입니다. 실제 주소로 바꿔야 합니다.
LOGIN_URL = f"{BASE_URL}/api/auth/login"
FATIGUE_API_URL = f"{BASE_URL}/api/eye-fatigue/"

# ❗️ 테스트할 계정 정보 입력 (seed.py를 실행했다면 기본 비번은 password123)
TEST_USER_EMAIL = "test@example.com"  # << 본인 테스트용 이메일로 변경
TEST_USER_PASSWORD = "password123"


# --- 설정값 (튜닝을 위해 이 값을 조정하세요) ---
# EAR 임계값: 이 값보다 작아지면 눈을 감은 것으로 판단
EAR_THRESHOLD = 0.30
# 연속 프레임: EAR 임계값보다 낮은 상태가 이 프레임 수만큼 지속되어야 깜빡임으로 인정
EAR_CONSEC_FRAMES = 3
# 시선 임계값: 홍채의 상대적 위치가 이 값보다 작으면 왼쪽, 크면 오른쪽으로 판단
GAZE_THRESHOLD_LEFT = 3.3   # << 기존 0.35에서 수정
GAZE_THRESHOLD_RIGHT = 2.7  # << 기존 0.65에서 수정
# 분석 주기 (초): 이 시간마다 피로도를 계산하고 출력
ANALYSIS_PERIOD_SECONDS = 60
OUTPUT_FILENAME = "fatigue_log.json"

# --- MediaPipe Face Mesh 초기화 ---
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,  # 눈 주변 랜드마크 정밀도 향상
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# --- 눈, 홍채 랜드마크 인덱스 정의 ---
LEFT_EYE = [33, 160, 158, 133, 153, 144]
RIGHT_EYE = [362, 385, 387, 263, 373, 380]
LEFT_IRIS_CENTER = 473
RIGHT_IRIS_CENTER = 468


class EyeFatigueMonitor:
    """
    눈의 피로도를 실시간으로 추적하고 분석하는 클래스.
    - 눈 깜빡임, 초점 시간 등을 측정하여 피로도 점수를 계산합니다.
    """

    def __init__(self):
        """모니터 초기화"""
        # 데이터 누적 변수
        self.blink_count = 0
        self.stable_gaze_durations = []
        
        # 상태 추적 변수
        self.blink_frame_counter = 0
        self.last_gaze_direction = "CENTER"
        self.stable_gaze_start_time = time.time()
        self.analysis_start_time = time.time()
        self.jwt_token = None  # 👈 로그인 후 받은 JWT 토큰을 저장할 변수 추가

    def _euclidean(self, p1, p2):
        """두 점 사이의 유클리드 거리를 계산합니다."""
        return math.hypot(p2[0] - p1[0], p2[1] - p1[1])

    def _get_ear(self, eye_landmarks):
        """눈 랜드마크로부터 EAR(Eye Aspect Ratio) 값을 계산합니다."""
        A = self._euclidean(eye_landmarks[1], eye_landmarks[5])
        B = self._euclidean(eye_landmarks[2], eye_landmarks[4])
        C = self._euclidean(eye_landmarks[0], eye_landmarks[3])
        return (A + B) / (2.0 * C)

    def process_frame(self, frame):
        """입력된 프레임을 처리하여 눈 관련 지표를 업데이트하고 화면에 정보를 그립니다."""
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb)
        gaze_direction_latest = self.last_gaze_direction

        if results.multi_face_landmarks:
            for face_landmarks in results.multi_face_landmarks:
                h, w, _ = frame.shape
                
                # --- 1. EAR 계산 및 깜빡임 감지 ---
                left_eye = [(int(face_landmarks.landmark[i].x * w), int(face_landmarks.landmark[i].y * h)) for i in LEFT_EYE]
                right_eye = [(int(face_landmarks.landmark[i].x * w), int(face_landmarks.landmark[i].y * h)) for i in RIGHT_EYE]
                ear = (self._get_ear(left_eye) + self._get_ear(right_eye)) / 2.0
                
                if ear < EAR_THRESHOLD:
                    self.blink_frame_counter += 1
                else:
                    if self.blink_frame_counter >= EAR_CONSEC_FRAMES:
                        self.blink_count += 1
                    self.blink_frame_counter = 0

                # --- 2. 시선 방향 추정 ---
                eye_left_lm = face_landmarks.landmark[LEFT_EYE[0]]
                eye_right_lm = face_landmarks.landmark[LEFT_EYE[3]]
                iris_center_lm = face_landmarks.landmark[LEFT_IRIS_CENTER]
                eye_width = (eye_right_lm.x - eye_left_lm.x)
                
                relative_iris_pos = 0.5 # 기본값은 정면
                if eye_width != 0:
                    relative_iris_pos = (iris_center_lm.x - eye_left_lm.x) / eye_width

                    # --- 수정된 시선 판단 로직 ---
                    if relative_iris_pos > GAZE_THRESHOLD_LEFT:
                        gaze_direction_latest = "LEFT"
                    elif relative_iris_pos < GAZE_THRESHOLD_RIGHT:
                        gaze_direction_latest = "RIGHT"
                    else:
                        gaze_direction_latest = "CENTER"
                
                # --- 3. 안정적 시선 유지 시간 측정 ---
                if gaze_direction_latest != self.last_gaze_direction:
                    duration = time.time() - self.stable_gaze_start_time
                    self.stable_gaze_durations.append(duration)
                    self.stable_gaze_start_time = time.time()
                self.last_gaze_direction = gaze_direction_latest

                # --- 4. 화면에 디버그 정보 그리기 ---
                for (x, y) in left_eye + right_eye:
                    cv2.circle(frame, (x, y), 2, (0, 255, 0), -1)
                cv2.putText(frame, f"EAR: {ear:.2f}", (30, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)
                cv2.putText(frame, f"Gaze Pos: {relative_iris_pos:.2f}", (30, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 255), 2)
                cv2.putText(frame, f"Gaze: {gaze_direction_latest}", (30, 120), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        

        
        # 주기적으로 피로도 분석 실행
        self._run_analysis()
    
                

    def _run_analysis(self):
        """설정된 분석 주기가 되면 피로도를 계산하고 결과를 출력 및 저장합니다."""
        if time.time() - self.analysis_start_time >= ANALYSIS_PERIOD_SECONDS:
            bpm = self.blink_count
            
            final_gaze_duration = time.time() - self.stable_gaze_start_time
            self.stable_gaze_durations.append(final_gaze_duration)
            max_stable_gaze_time = max(self.stable_gaze_durations) if self.stable_gaze_durations else 0

            print(f"\n--- [ {ANALYSIS_PERIOD_SECONDS}초 분석 결과 ] ---")
            print(f"분당 깜빡임 (BPM): {bpm} 회")
            print(f"최대 시선 고정 시간: {max_stable_gaze_time:.2f} 초")

            # --- 1. 지표별 건강 점수 산출 ---
            blink_score = (bpm / 30) * 100
            if blink_score > 100:
                blink_score = 100

            gaze_score = (1 - (max_stable_gaze_time / 60)) * 100
            if gaze_score < 0:
                gaze_score = 0
            
            # --- 2. 최종 건강 점수 계산 ---
            total_health_score = (blink_score * 0.6) + (gaze_score * 0.4)
            
            # --- 3. 결과 해석 ---
            fatigue_status = "매우 나쁨 😵"
            if total_health_score > 70:
                fatigue_status = "양호함 😊"
            elif total_health_score > 40:
                fatigue_status = "주의 필요 😐"
            
            print(f"눈 건강 점수: {total_health_score:.1f} / 100")
            print(f"현재 눈 상태: {fatigue_status}")
            print("--------------------------\n")

            # --- 4. 전송할 데이터 준비 ---
            # 👇 바로 이 부분이 빠져있었습니다!
            log_data = {
                "bpm": bpm,
                "max_stable_gaze_time": round(max_stable_gaze_time, 2),
                "health_score": round(total_health_score, 1),
                "status": fatigue_status
            }

            # --- 5. 백엔드 서버로 데이터 전송 ---
            # (이제 _save_log는 사용하지 않습니다.)
            self._send_to_backend(log_data)

            # --- 6. 다음 분석을 위해 변수 초기화 ---
            self._reset_analysis_variables()


    def _get_jwt_token(self):
        """서버에 로그인하여 JWT 토큰을 받아옵니다."""
        try:
            # FastAPI의 로그인 형식에 맞춰 아이디와 비밀번호를 보냅니다.
            login_data = {"username": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
            response = requests.post(LOGIN_URL, data=login_data)

            if response.status_code == 200:
                print(">> 로그인 성공! JWT 토큰을 발급받았습니다.")
                # 성공 시, 받은 토큰을 클래스 변수에 저장합니다.
                self.jwt_token = response.json().get("access_token")
                return True
            else:
                print(f">> 로그인 실패: {response.status_code} - {response.text}")
                return False
        except requests.exceptions.RequestException as e:
            print(f">> 서버 연결 오류 (로그인): {e}")
            return False

    def _send_to_backend(self, data_to_send): 
        """분석 결과를 백엔드 서버로 전송합니다."""
        if not self.jwt_token:
            print(">> 경고: JWT 토큰이 없어 서버로 전송할 수 없습니다.")
            return

        headers = {"Authorization": f"Bearer {self.jwt_token}"}
        try:
            # 👈 여기서 log_data 대신 data_to_send를 사용해야 합니다.
            response = requests.post(FATIGUE_API_URL, json=data_to_send, headers=headers)

            if response.status_code == 200:
                print(">> 서버로 분석 결과 전송 성공!")
            else:
                print(f">> 서버 전송 실패: {response.status_code} - {response.text}")
        except requests.exceptions.RequestException as e:
            print(f">> 서버 연결 오류: {e}")

    def _reset_analysis_variables(self):
        """다음 분석을 위해 변수를 초기화합니다."""
        self.analysis_start_time = time.time()
        self.blink_count = 0
        self.stable_gaze_durations = []
        self.stable_gaze_start_time = time.time() # 시선 유지 시간도 초기화

if __name__ == "__main__":
    cap = cv2.VideoCapture(0)
    monitor = EyeFatigueMonitor()

    print("AI 분석을 시작합니다. 먼저 서버에 로그인을 시도합니다...")
    login_successful = monitor._get_jwt_token() # 프로그램 시작 시 딱 한 번 로그인

    if login_successful:
        print("로그인 성공! 실시간 눈 피로 분석을 시작합니다. (종료: 'q' 키)")
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            frame = cv2.flip(frame, 1)

            # 이 함수가 내부적으로 분석, 결과 출력, 서버 전송까지 모두 처리합니다.
            monitor.process_frame(frame)

            cv2.imshow("Eye Fatigue Monitor", frame)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
    else:
        print("로그인에 실패하여 프로그램을 종료합니다. 서버 주소와 계정 정보를 확인하세요.")

    cap.release()
    cv2.destroyAllWindows()
