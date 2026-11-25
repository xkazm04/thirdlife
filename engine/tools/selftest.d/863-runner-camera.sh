# H1g (25 Nov 2026, lane G4's "keep the camera steady" note): the runner reports how much the active camera turns and
# travels (kernel/runner/camyaw.gd; metrics camera_yaw_p90_dps, camera_yaw_max_dps, camera_move_p90_mps, camera_move_max_mps).
# runner.camera_chase: ex_car's chase camera follows the car through the slalom: it travels.
# runner.camera_still: ex_bounce's fixed front view: 0 turned, 0 travelled.
check runner.camera_chase 0 bot "--pack=$EX/ex_car" --frames=5400 -- '"camera_move_p90_mps":([1-9][0-9]*|[1-9][0-9]*\.[0-9]+)[,}]' '"camera_yaw_p90_dps":[0-9.]+,' '"camera_yaw_max_dps":[0-9.]+,' '"camera_move_max_mps":[0-9.]+[,}]'
check runner.camera_still 0 smoke "--pack=$EX/ex_bounce" --frames=600 -- '"camera_yaw_p90_dps":0,' '"camera_move_p90_mps":0,'
