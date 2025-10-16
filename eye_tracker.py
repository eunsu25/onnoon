import cv2
import mediapipe as mp
import time
import math
import json  # << JSON 라이브러리 추가
from datetime import datetime  # << 시간 기록을 위한 라이브러리 추가

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

    def __init__(self, ear_threshold, analysis_period):
        """모니터 초기화"""
        # 데이터 누적 변수
        self.blink_count = 0
        self.stable_gaze_durations = []
        
        # 상태 추적 변수
        self.blink_frame_counter = 0
        self.last_gaze_direction = "CENTER"
        self.stable_gaze_start_time = time.time()
        self.analysis_start_time = time.time()

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

            # --- 1. 지표별 건강 점수 산출 (점수가 높을수록 좋음) ---
            
            # A. 깜빡임 건강 점수 (0~30회 범위를 0~100점으로 변환)
            # 30회 이상 깜빡이면 만점(100점), 0회면 0점
            blink_score = (bpm / 30) * 100
            if blink_score > 100:  # 100점을 넘지 않도록 제한
                blink_score = 100

            # B. 시선 고정 건강 점수 (0~60초 범위를 100~0점으로 변환)
            # 시선 고정 시간이 0초에 가까울수록 만점(100점), 60초 이상이면 0점
            gaze_score = (1 - (max_stable_gaze_time / 60)) * 100
            if gaze_score < 0:  # 0점 밑으로 내려가지 않도록 제한
                gaze_score = 0
            
            # --- 2. 최종 건강 점수 계산 ---
            # 가중치: 깜빡임 60%, 시선 고정 40%
            total_health_score = (blink_score * 0.6) + (gaze_score * 0.4)
            
            # --- 3. 결과 해석 (점수가 높을수록 긍정적) ---
            fatigue_status = "매우 나쁨 😵"
            if total_health_score > 70:
                fatigue_status = "양호함 😊"
            elif total_health_score > 40:
                fatigue_status = "주의 필요 😐"
            
            print(f"눈 건강 점수: {total_health_score:.1f} / 100")
            print(f"현재 눈 상태: {fatigue_status}")
            print("--------------------------\n")

            # --- 4. JSON 로그 저장 ---
            self._save_log({
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "bpm": bpm,
                "max_stable_gaze_time": round(max_stable_gaze_time, 2),
                "health_score": round(total_health_score, 1), # 'fatigue_score' -> 'health_score'
                "status": fatigue_status
            })

            # --- 5. 다음 분석을 위해 변수 초기화 ---
            self._reset_analysis_variables()

    def _save_log(self, new_log_data):
        """분석 결과를 JSON 파일에 추가하여 저장합니다."""
        try:
            with open(OUTPUT_FILENAME, 'r', encoding='utf-8') as f:
                logs = json.load(f)
        except FileNotFoundError:
            logs = []
        logs.append(new_log_data)
        with open(OUTPUT_FILENAME, 'w', encoding='utf-8') as f:
            json.dump(logs, f, ensure_ascii=False, indent=4)

    def _reset_analysis_variables(self):
        """다음 분석을 위해 변수를 초기화합니다."""
        self.analysis_start_time = time.time()
        self.blink_count = 0
        self.stable_gaze_durations = []
        self.stable_gaze_start_time = time.time() # 시선 유지 시간도 초기화

if __name__ == "__main__":
    cap = cv2.VideoCapture(0)
    monitor = EyeFatigueMonitor(ear_threshold=EAR_THRESHOLD, analysis_period=ANALYSIS_PERIOD_SECONDS)

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        frame = cv2.flip(frame, 1)

        # 프레임 처리 및 눈 상태 업데이트
        monitor.process_frame(frame)
        

        # 화면에 프레임 표시
        cv2.imshow("Eye Fatigue Monitor", frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()
