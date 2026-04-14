# Power Maintenance Runbook

정전, 랙 전원 작업, UPS 테스트처럼 전체 또는 일부 클러스터 전원을 내릴 때 쓰는 운영 메모.

대상 환경:

- Repo / Registry / NFS / MAAS: `10.250.254.1`
- OpenStack stack1: `10.250.254.11`
- OpenStack stack2: `10.250.254.12`
- OpenStack stack3: `10.250.254.13`
- Kolla inventory: `/root/multinode`
- Kolla venv: `/root/kolla-venv`

## 원칙

1. `10.250.254.1`는 마지막에 내리고, 가장 먼저 올린다.
2. OpenStack보다 Ceph 상태를 먼저 안정화한다.
3. 전체 계획 정전이면 OpenStack을 먼저 멈추고, 그 다음 Ceph 쪽을 정리한다.
4. 전체 OSD 중단 전에는 `noout`를 걸어 불필요한 재배치를 막는다.
5. 전원 복구 후에는 Ceph 쿼럼과 OSD up/in 상태를 먼저 보고, 그 다음 OpenStack을 올린다.

## 작업 전 확인

배포 노드에서:

```bash
cd /root/openstack/deploy-airgap
./scripts/kolla-run.sh prechecks
```

`stack1`에서:

```bash
source /root/kolla-venv/bin/activate
source /etc/kolla/admin-openrc.sh 2>/dev/null || source /etc/kolla/admin-openrc-system.sh

ceph -s
openstack compute service list -f table
openstack volume service list -f table
openstack network agent list -f table
openstack volume type list -f table
```

NFS 확인이 필요하면:

```bash
showmount -e 10.250.254.1
mount -t nfs 10.250.254.1:/DATA/nfs/cinder /mnt/test-nfs
umount /mnt/test-nfs
```

작업 전에 확인할 것:

- 중요한 VM의 종료 가능 여부
- 볼륨 생성/삭제나 이미지 업로드 같은 장시간 작업 유무
- MAAS DHCP/PXE 작업 중 장비 유무
- `ceph -s`가 최소한 `HEALTH_OK` 또는 계획된 경고만 있는지

## 전체 정전 시 내리는 순서

### 1. OpenStack 정지 준비

`stack1`에서:

```bash
source /root/kolla-venv/bin/activate
ceph osd set noout
```

참고:

- `noout`는 계획 정지 동안 OSD 재배치를 막기 위한 것
- 이 플래그는 작업 후 반드시 해제해야 한다

### 2. OpenStack 컨테이너 정지

배포 노드에서:

```bash
cd /root/openstack/deploy-airgap
./scripts/kolla-run.sh stop
```

또는 `stack1`에서 직접:

```bash
source /root/kolla-venv/bin/activate
kolla-ansible stop -i /root/multinode
```

확인:

```bash
docker ps
```

주의:

- Kolla의 `stop`은 컨테이너를 내려놓는 용도다
- 이후 재기동은 `deploy-containers` 또는 `deploy`로 올리는 쪽으로 잡는다

### 3. 스택 노드 종료

권장 순서:

1. `stack3`
2. `stack2`
3. `stack1`

예:

```bash
ssh root@10.250.254.13 shutdown -h now
ssh root@10.250.254.12 shutdown -h now
ssh root@10.250.254.11 shutdown -h now
```

### 4. 마지막으로 `10.250.254.1` 종료

이 서버는 다음 역할을 같이 갖는다:

- local apt repo
- local docker registry
- NFS
- MAAS

가능하면 모든 stack 노드가 내려간 뒤 마지막에 종료한다.

```bash
shutdown -h now
```

## 전체 정전 후 올리는 순서

### 1. `10.250.254.1` 먼저 기동

확인:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
showmount -e 127.0.0.1
```

필요 확인:

- NFS export 정상
- registry 접근 정상
- repo HTTPS 응답 정상

### 2. Ceph 쿼럼 확보용으로 `stack1`, `stack2` 먼저

권장 순서:

1. `stack1`
2. `stack2`
3. `stack3`

이유:

- MON 3개 구성에서 먼저 2개가 올라와야 과반 쿼럼 확보가 쉽다

### 3. Ceph 상태 확인

`stack1`에서:

```bash
source /root/kolla-venv/bin/activate
ceph -s
ceph orch ps
ceph osd tree
```

확인 기준:

- MON quorum 정상
- OSD가 모두 `up` / `in`
- PG가 최종적으로 `active+clean`

### 4. `noout` 해제

`stack1`에서:

```bash
ceph osd unset noout
ceph -s
```

### 5. OpenStack 컨테이너 기동

배포 노드에서:

```bash
cd /root/openstack/deploy-airgap
./scripts/kolla-run.sh deploy-containers
```

직접 실행:

```bash
source /root/kolla-venv/bin/activate
kolla-ansible deploy-containers -i /root/multinode
```

다음 경우에는 `deploy` 또는 `reconfigure`를 쓴다:

- 이미지가 바뀜
- 설정을 수정함
- `deploy-containers`로 서비스가 충분히 안 올라옴

예:

```bash
./scripts/kolla-run.sh deploy
./scripts/kolla-run.sh reconfigure --tags cinder
```

### 6. OpenStack 사후 점검

배포 노드에서:

```bash
cd /root/openstack/deploy-airgap
./scripts/postcheck-openstack.sh
```

추가 확인:

```bash
source /root/kolla-venv/bin/activate
source /etc/kolla/admin-openrc.sh 2>/dev/null || source /etc/kolla/admin-openrc-system.sh

openstack compute service list -f table
openstack volume service list -f table
openstack network agent list -f table
openstack hypervisor list -f table
```

NFS backend 확인:

```bash
openstack volume type list -f table
openstack volume create --type nfs --size 1 nfs-power-test
openstack volume show nfs-power-test -f yaml
openstack volume delete nfs-power-test
```

## 단일 노드 유지보수

`stack1`, `stack2`, `stack3` 중 한 대만 내릴 때는 전체 정전보다 절차를 더 좁게 잡는다.

Ceph 쪽은 가능하면 호스트 단위 maintenance 명령을 우선 검토:

```bash
ceph orch host maintenance enter <hostname>
ceph orch host maintenance exit <hostname>
```

또는 최소한:

```bash
ceph orch host ok-to-stop <hostname>
ceph osd set noout
```

그 다음 필요한 Kolla 서비스만 부분 정지/재반영:

```bash
cd /root/openstack/deploy-airgap
./scripts/service-reconfig.sh nova --limit <hostname>
./scripts/service-reconfig.sh neutron --limit <hostname>
```

주의:

- `--limit`는 Kolla 문서에서도 완전히 권장되는 경로는 아니다
- 호스트 단위 작업은 먼저 `ceph orch host ok-to-stop`로 안전성부터 확인한다

## 작업 종료 체크리스트

- `ceph osd dump | grep noout` 결과가 비어 있음
- `ceph -s` 정상
- `openstack compute service list` 정상
- `openstack volume service list` 정상
- `openstack network agent list` 정상
- `docker ps`에서 핵심 서비스 정상
- `showmount -e 10.250.254.1` 정상
- NFS test volume 생성/삭제 정상

## 장애 시 우선 확인

### Ceph가 안 살아날 때

`stack1`에서:

```bash
ceph -s
ceph orch ps
ceph quorum_status --format json-pretty
```

먼저 볼 것:

- MON quorum
- OSD down 개수
- 네트워크 문제

### OpenStack API가 안 뜰 때

`stack1`에서:

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
docker logs keystone 2>&1 | tail -n 50
docker logs haproxy 2>&1 | tail -n 50
docker logs mariadb 2>&1 | tail -n 50
```

필요 시:

```bash
cd /root/openstack/deploy-airgap
./scripts/kolla-run.sh deploy-containers
./scripts/postcheck-openstack.sh
```
