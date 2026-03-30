deploy-airgap (provider-only / no-tenant / airgap-oriented)

의도
- deploy-nontenant와 동일한 네트워크/서비스 구조를 유지하되, 외부 인터넷 대신 내부 artifact 허브(현재 192.168.0.216)를 바라보도록 준비한 배포 세트.

핵심 차이
- Docker 패키지: 내부 apt repo
- Python 패키지: 내부 PyPI/simple
- Kolla 소스: 외부 git clone 대신 control node의 로컬 소스 디렉터리
- Ansible Galaxy: 내부 Galaxy/mirror endpoint 사용 가정
- Ubuntu/Alloy base image: 내부 images URL
- Grafana Alloy apt repo: 내부 apt repo

사전 준비물
- airgap_kolla_source_dir 에 kolla-ansible 소스 미리 준비
- artifact host 에 Docker apt mirror / Grafana apt mirror / PyPI mirror / image files 준비
- local_registry 에 Kolla/OpenStack/monitoring 이미지를 미리 push
