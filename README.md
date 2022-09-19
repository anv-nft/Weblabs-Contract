# Web Labs Smart Contracts
- KIP17-EachTokenPausable
  - 토큰 별 정지 기능이 존재하는 KIP17
- Reveal
  - 리빌을 수행하는 컨트랙트
  - 단, 소각 할 토큰(유저)은 리빌 컨트랙트에 Approve를 주어야 하며,
  - 새롭게 민팅 될 컨트랙트(컨트랙트 오너)는 리빌 컨트랙트에게 addMinter를 실행해주어야 함
