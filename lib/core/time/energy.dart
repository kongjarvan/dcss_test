import '../entity/actor.dart';

/// 게임 시간 단위는 aut. 10 aut = 1턴.
/// 모든 행동은 aut 단위의 소요 시간(비용)을 가진다.
const autPerTurn = 10;

/// 기본 속도. 속도 10인 몬스터는 10 aut마다 10 aut짜리 행동을 한 번 한다.
const normalSpeed = 10;

/// 몬스터의 에너지(행동력) 관리.
///
/// - 플레이어가 T aut짜리 행동을 하면 각 몬스터는 `T × 속도`만큼 에너지를 얻는다.
/// - 에너지가 양수인 동안 행동하고, 행동마다 `비용 × normalSpeed`를 소모한다.
/// - 에너지가 음수(빚)로 넘어갈 수 있으므로 긴 시간 동안의 행동 빈도가 정확하다.
///   예) 속도 20 → 플레이어 1턴에 2번 행동, 비용 15짜리 공격 → 1.5턴에 1번.
abstract final class EnergyScheduler {
  static void grant(Monster monster, int aut) =>
      monster.energy += aut * monster.speed;

  static bool canAct(Monster monster) => monster.energy > 0;

  static void spend(Monster monster, int costAut) =>
      monster.energy -= costAut * normalSpeed;
}
