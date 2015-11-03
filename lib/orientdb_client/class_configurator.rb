class ClassConfigurator
  def initialize(class_name, node)
    @class_name = class_name
    @node = node
  end

  def property(property_name, type, options = {})
    @node.create_property(@class_name, property_name, type, options)
  end
end
