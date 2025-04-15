# init.sh
set -euo pipefail

echo "▶️ WAX Init 시작"

### [1] 환경변수 로드 ###
SERVER_TAR="${SERVER_TAR:?SERVER_TAR 환경변수가 필요합니다}"
GATEWAY_TAR="${GATEWAY_TAR:?GATEWAY_TAR 환경변수가 필요합니다}"
SERVICE_HOSTS="${SERVICE_HOSTS:?SERVICE_HOSTS 환경변수가 필요합니다}"

TEMP_DIR="${TEMP_DIR:-/tmp}"
SERVER_ROOT="${SERVER_ROOT:-/opt/wax/server}"
GATEWAY_ROOT="${GATEWAY_ROOT:-/opt/wax/gateway}"
NODE_ROOT="${NODE_ROOT:-/opt/wax/nodejs}"
MGO_ROOT="${MGO_ROOT:-/opt/wax/mongodb}"

MGODB_HOST="${MGODB_HOST:-localhost}"
MGODB_PORT="${MGODB_PORT:-27017}"
MGODB_USER="${MGODB_USER:-apadmin}"
MGODB_DB="${MGODB_DB:-waxdb}"
MGODB_TLS=true
MGODB_CERT="${MGODB_CERT:-${MGO_ROOT}/etc/mongodb-cert.pem}"
MGODB_KEY="${MGODB_KEY:-${MGO_ROOT}/etc/mongodb-cert.key}"
MGODB_CA="${MGODB_CA:-${MGO_ROOT}/etc/mongodb-cert.crt}"
MGODB_INDIRECT=false

REGULATION="${REGULATION:-BASE}"
DEBUG="${DEBUG:-true}"
VERBOSE="${VERBOSE:-false}"
TELNET_PROTOCOL="${TELNET_PROTOCOL:-false}"
FTP_PROTOCOL="${FTP_PROTOCOL:-false}"
DB_PROTOCOL="${DB_PROTOCOL:-false}"
HTTPS_PROTOCOL="${HTTPS_PROTOCOL:-true}"

### [2] 디렉토리 구성 ###
echo "📁 디렉토리 생성"
mkdir -p "${SERVER_ROOT}"/{bin,etc,log,audit}
mkdir -p "${GATEWAY_ROOT}" "${NODE_ROOT}" "${MGO_ROOT}"

### [3] 압축 해제 ###
echo "📦 서버/게이트와이 압축 해제"
tar xvf "${SERVER_TAR}" -C "${SERVER_ROOT}" >/dev/null
tar xvf "${GATEWAY_TAR}" -C "${GATEWAY_ROOT}" >/dev/null

chown -R root:root "${SERVER_ROOT}" "${GATEWAY_ROOT}"

### [4] configdb 설정 ###
CONFIGDB="${SERVER_ROOT}/bin/configdb"
if [[ -x "$CONFIGDB" ]]; then
  echo "⚙️ configdb 설정"
  "$CONFIGDB" set \
    -mgohost "$MGODB_HOST" \
    -mgoport "$MGODB_PORT" \
    -mgouser "$MGODB_USER" \
    -mgodb "$MGODB_DB" \
    -mgotls "$MGODB_TLS" \
    -mgocert "$MGODB_CERT" \
    -mgopriv "$MGODB_KEY" \
    -mgoca "$MGODB_CA" \
    -mgoindirect "$MGODB_INDIRECT"

  echo "✅ configdb 연결 테스트"
  "$CONFIGDB" test
else
  echo "⚠️ configdb 바이너리가 존재하지 않음: ${CONFIGDB}"
fi

### [5] 인증서 생성 ###
CERT_HOSTS="localhost,127.0.0.1,${SERVICE_HOSTS}"

TCRTWEBKEY="${SERVER_ROOT}/bin/tcrtwebkey"
TCRTCOMKEY="${SERVER_ROOT}/bin/tcrtcomkey"
TCRTRDGKEY="${SERVER_ROOT}/bin/tcrtrdgkey"

[[ -x "$TCRTWEBKEY" ]] && "$TCRTWEBKEY" -duration 8760h0m0s -host "$CERT_HOSTS"
[[ -x "$TCRTCOMKEY" ]] && "$TCRTCOMKEY" -duration 87600h0m0s -host "$CERT_HOSTS"
[[ "$REGULATION" == "BASE" && -x "$TCRTRDGKEY" ]] && "$TCRTRDGKEY" -duration 8760h0m0s -host "$CERT_HOSTS"

### [6] managewax 시작 ###
MANAGEWAX="${SERVER_ROOT}/bin/managewax"
[[ -x "$MANAGEWAX" ]] && "$MANAGEWAX" dbinit -t ALL -f --audit "${SERVER_ROOT}/audit"

### [7] gtconfig 설정 ###
GTCONFIG="${GATEWAY_ROOT}/bin/config"
if [[ -x "$GTCONFIG" ]]; then
  "$GTCONFIG" -set init
  "$GTCONFIG" -q -set config \
    -sslkeypath "${SERVER_ROOT}/etc/https-key.pem" \
    -sslcertpath "${SERVER_ROOT}/etc/https-cert.pem"

  MODE_OPTS=""
  [[ "$TELNET_PROTOCOL" == "true" ]] && MODE_OPTS+=" -telnet"
  [[ "$FTP_PROTOCOL" == "true" ]] && MODE_OPTS+=" -ftp"
  [[ "$DB_PROTOCOL" == "true" ]] && MODE_OPTS+=" -db"
  [[ "$HTTPS_PROTOCOL" == "true" ]] && MODE_OPTS+=" -https"

  "$GTCONFIG" -q -set mode $MODE_OPTS
fi

echo "🎉 설치 완료!"
