#!/bin/bash
set -euo pipefail

echo "▶️ WAX Init (데몬형) 시작"

### [1] 환경변수 로드 ###
SERVER_TAR="${SERVER_TAR:-/opt/input/Server.tar}"
GATEWAY_TAR="${GATEWAY_TAR:-/opt/input/Gateway.tar}"
SERVICE_HOSTS="${SERVICE_HOSTS:-127.0.0.1}"

SERVER_ROOT="/opt/wax/server"
GATEWAY_ROOT="/opt/wax/gateway"

### [2] 디렉토리 생성 및 압축 해제 ###
echo "📦 제품 압축 해제 중..."
mkdir -p "$SERVER_ROOT" "$GATEWAY_ROOT"
tar xvf "$SERVER_TAR" -C "$SERVER_ROOT" 
tar xvf "$GATEWAY_TAR" -C "$GATEWAY_ROOT" 

# 실행권한 보정
chmod +x "${SERVER_ROOT}/bin/"*
chmod +x "${GATEWAY_ROOT}/bin/"*

### [3] 인증서 생성 ###
CERT_HOSTS="localhost,127.0.0.1,${SERVICE_HOSTS}"

TCRTWEBKEY="${SERVER_ROOT}/bin/tcrtwebkey"
TCRTCOMKEY="${SERVER_ROOT}/bin/tcrtcomkey"
TCRTRDGKEY="${SERVER_ROOT}/bin/tcrtrdgkey"

echo "ls ${SERVER_ROOT}/bin"
[[ -x "$TCRTWEBKEY" ]] && "$TCRTWEBKEY" -duration 8760h0m0s -host "$CERT_HOSTS"
[[ -x "$TCRTCOMKEY" ]] && "$TCRTCOMKEY" -duration 87600h0m0s -host "$CERT_HOSTS"
[[ -x "$TCRTRDGKEY" ]] && "$TCRTRDGKEY" -duration 8760h0m0s -host "$CERT_HOSTS"

### [4] Gateway 설정 ###
GTCONFIG="${GATEWAY_ROOT}/bin/config"
if [[ -x "$GTCONFIG" ]]; then
  "$GTCONFIG" -set init
  "$GTCONFIG" -q -set config \
    -sslkeypath "${SERVER_ROOT}/etc/https-key.pem" \
    -sslcertpath "${SERVER_ROOT}/etc/https-cert.pem"
  "$GTCONFIG" -q -set mode -https
fi

### [5] wdog 실행 (백그라운드) ###
WDOGD="${SERVER_ROOT}/bin/wdogd"
if [[ -x "$WDOGD" ]]; then
  echo "🚀 wdogd 실행 중 (백그라운드 모드)..."
  "$WDOGD" -reg &
  sleep 2
else
  echo "[ERROR] wdogd 실행 파일 없음"
  exit 1
fi

### [6] tdog으로 프로세스 등록 예시 ###
TDOG="${SERVER_ROOT}/bin/tdog"
if [[ -x "$TDOG" ]]; then
  echo "🔧 tdog 등록 중..."
  "$TDOG" add -n wauth -e "${SERVER_ROOT}/bin/wauth" --start
  "$TDOG" add -n wresource -e "${SERVER_ROOT}/bin/wresource" --start
fi

### [7] 컨테이너 유지용 (포그라운드로 wdog 실행) ###
echo "🟢 컨테이너 유지: wdogd 메인 PID로 전환"
exec tail -f /dev/null
