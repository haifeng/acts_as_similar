# ActsAsSimilar
module Freezzo
  module ActsAsSimilar
    def self.included(base)
      base.extend(ActsMethods)
    end
    
    module ActsMethods
      def acts_as_similar(on, options = {})
        defaults   = {}
        self_assoc = false
        options    = defaults.merge(options)

        if on.is_a?(Hash)
          self_assoc = true
          options    = on
          on         = self.table_name.to_sym
        end
        
        # We have an association
        if on
          assoc           = self.reflections[on.to_sym]
          if assoc
            through_assoc   = assoc.through_reflection
            options[:assoc] = assoc.name
            on_class_name   = assoc.class_name
   
            options[:on_singular] ||= on_class_name.underscore
            options[:on_class]    ||= assoc.klass
          end

          options[:class] = self
         
          if through_assoc
            options[:through_singular] ||= through_assoc.class_name.downcase
            options[:through_class]    ||= through_assoc.klass
          end
        end
        
        # Method to find similar items
        define_method "similar" do
          options[:fields] = [*options[:field]]
          # First grab all the items from this class that we want to look for
          unless self_assoc
            if options[:through_class]
              Logic.similar_by_through(self, options)
            else
              Logic.similar_by_association(self, options)
            end
          else
            Logic.similar_by_self(self, options)
          end
        end
      end

      module Logic
        ########################################################################################################
        def self.similar_by_through(object, options)
          table      = options[:through_class].table_name
          field      = options[:on_singular] + "_id"
          self_table = options[:class].class_name.downcase
          items      = object.__send__(options[:assoc]).collect {|si| si.id }
          conditions = "#{table}.#{self_table}_id != ? and #{table}.#{field} in (?)"
          
          Logic.find(object.class, [conditions, object.id, items], table)
        end

        ########################################################################################################
        def self.similar_by_association(object, options)
          table      = options[:on_class].table_name
          items      = object.__send__(options[:assoc]).collect {|si| options[:fields].collect {|f| si.__send__(f) } }.flatten
          conditions = options[:fields].collect {|f| "#{table}.#{f} in (?)" }.join(" and ")

          Logic.find(options[:class], [conditions, items], table)
        end

        ########################################################################################################
        def self.similar_by_self(object, options)
          items      = options[:fields].collect {|f| "%#{object.__send__(f)}%".downcase }
          conditions = options[:fields].collect {|f| Logic.build_condition(object, f) }.join(" and ")

          Logic.find(object.class, [[conditions] + items].flatten)
        end

        ########################################################################################################
        def self.build_condition(object, field)
          value = object.__send__(field)
          table = object.class.table_name

          if value.is_a?(String)
            "#{table}.id != #{object.id} and #{table}.#{field} like ?"
          else
            "#{table}.id != #{object.id} and #{table}.#{field} in (?)"
          end
        end

        ########################################################################################################
        def self.find(object, conditions, include = nil)
          object.find(:all, :include => include, :conditions => conditions)
        end
      end
    end
  end
end
