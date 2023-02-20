# encoding: UTF-8


class Array

  def pretty_join
    if self.count < 2
      return self.join('')
    else
      ary = self.dup
      dernier = ary.pop
      return ary.join(', ') + ' et ' + dernier
    end
  end

end #/class Array
