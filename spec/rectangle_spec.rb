require './global'

describe Rectangle do
	before :each do
		@rect1 = Rectangle.new 0, 0, 10, 10
	end
	
	subject { @rect1 }
	it { should respond_to :x }
	it { should respond_to :y }
	it { should respond_to :w }
	it { should respond_to :h }
	it { should respond_to :intersects }
	
	describe "when it intersects another rectangle" do
		it "should report intersection" do
			@rect2 = Rectangle.new 5, 5, 10, 10
			@rect1.intersects(@rect2).should be_true
			@rect2 = Rectangle.new -5, -5, 10, 10
			@rect1.intersects(@rect2).should be_true
		end
	end
	
	describe "when it does not intersect another rectangle" do
		it "should not report intersection" do
			@rect2 = Rectangle.new 15, 15, 10, 10
			@rect1.intersects(@rect2).should be_false
			@rect2 = Rectangle.new -15, -15, 10, 10
			@rect1.intersects(@rect2).should be_false
		end
	end
	
	describe "when it is adjacent to another rectangle" do
		it "should not report intersection" do
			@rect2 = Rectangle.new 10, 0, 10, 10
			@rect1.intersects(@rect2).should be_false
			@rect2 = Rectangle.new -10, 0, 10, 10
			@rect1.intersects(@rect2).should be_false
		end
	end
end
