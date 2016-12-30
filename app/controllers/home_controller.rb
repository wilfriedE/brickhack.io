class HomeController < ApplicationController
  def index
    @event_schedule = Schedule.new("Event Schedule", "146w2Ozjkomtubbob03DWpUMN3vBOtCnxn_YCh82Vga0", "A1:E6", 0)
    render layout: "blank"
  end

  def comingsoon
    render layout: "blank"
  end

  def event
    render layout: "dayof"
  end
end
