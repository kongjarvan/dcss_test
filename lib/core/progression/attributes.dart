/// 플레이어 기본 능력치.
///
/// 각 능력치가 무엇에 영향을 주는지는 아직 정하지 않았다.
/// 효과가 정해지면 이 값을 읽어 전투 수치(CombatStats) 등을 계산하면 된다.
enum Attribute {
  strength('힘'),
  dexterity('민첩'),
  intelligence('지능');

  const Attribute(this.label);

  final String label;
}

class Attributes {
  Attributes({int strength = 10, int dexterity = 10, int intelligence = 10})
    : _values = {
        Attribute.strength: strength,
        Attribute.dexterity: dexterity,
        Attribute.intelligence: intelligence,
      };

  final Map<Attribute, int> _values;

  int operator [](Attribute attribute) => _values[attribute]!;

  void increase(Attribute attribute, [int amount = 1]) =>
      _values[attribute] = this[attribute] + amount;
}
