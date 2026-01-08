function init_sounds_channel(channel)
  if lb.get(channel, true) then
    sound.set_group_gain(channel, 1)
  else
    sound.set_group_gain(channel, 0)
  end
end

function smoothlyReduceChannel(channel)
  if lb.get(channel, true) then  
    local gain = 1
    local timer_id = nil
    timer_id = timer.delay(0.1, true, function ()
      gain = gain - 0.1

      if gain <= 0 then
        gain = 0
        timer.cancel(timer_id)
      end

      sound.set_group_gain(channel, gain)
    end)
  end
end

function smoothlyIncreaseChannel(channel)
  if lb.get(channel, true) then
    local gain = 0.1
    local timer_id = nil
    sound.set_group_gain(channel, gain)

    timer_id = timer.delay(0.1, true, function ()
      gain = gain + 0.1

      if gain >= 1 then
        gain = 1
        timer.cancel(timer_id)
      end
      sound.set_group_gain(channel, gain)
    end)
  end
end
