require_relative "test_helper"

class SubstitutionTest < Minitest::Test
  Types = Steep::AST::Types
  Substitution = Steep::Interface::Substitution

  def test_build
    s = Substitution.build([:a, :b],
                           [Types::Name.new_instance(name: :String), Types::Any.new],
                           instance_type: Types::Name.new_instance(name: :Integer),
                           module_type: Types::Name.new_singleton(name: :Object),
                           self_type: Types::Name.new_instance(name: :Float))

    assert_equal Types::Name.new_instance(name: :Integer), s.instance_type
    assert_equal Types::Name.new_singleton(name: :Object), s.module_type
    assert_equal Types::Name.new_instance(name: :Float), s.self_type
    assert_equal({ a: Types::Name.new_instance(name: :String), b: Types::Any.new }, s.dictionary)
  end

  def test_apply
    s = Substitution.build([:a, :b],
                           [Types::Name.new_instance(name: :String), Types::Any.new],
                           instance_type: Types::Name.new_instance(name: :Integer),
                           module_type: Types::Name.new_singleton(name: :Object),
                           self_type: Types::Name.new_instance(name: :Float))

    assert_equal Types::Name.new_instance(name: :String), Types::Var.new(name: :a).subst(s)
    assert_equal Types::Var.new(name: :x), Types::Var.new(name: :x).subst(s)

    assert_equal Types::Name.new_instance(name: :Array, args: [Types::Name.new_instance(name: :String)]),
                 Types::Name.new_instance(name: :Array, args: [Types::Var.new(name: :a)]).subst(s)

    assert_equal Types::Name.new_instance(name: :Integer), Types::Instance.new.subst(s)
    assert_equal Types::Name.new_singleton(name: :Object), Types::Class.new.subst(s)
    assert_equal Types::Name.new_instance(name: :Float), Types::Self.new.subst(s)

    assert_equal Types::Any.new,
                 Types::Union.build(types: [Types::Var.new(name: :a), Types::Var.new(name: :b)]).subst(s)
  end

  def test_except
    s = Substitution.build([:a, :b],
                           [Types::Name.new_instance(name: :String), Types::Any.new]).except([:a])

    assert_equal({ b: Types::Any.new }, s.dictionary)
  end
end
