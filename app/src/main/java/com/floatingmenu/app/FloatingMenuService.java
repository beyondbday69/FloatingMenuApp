package com.floatingmenu.app;

import android.app.Service;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.os.Build;
import android.os.IBinder;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.SeekBar;
import android.widget.TextView;

public class FloatingMenuService extends Service {
    private WindowManager mWindowManager;
    private View mFloatingView;
    private View collapsedView;
    private View expandedView;

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        mFloatingView = LayoutInflater.from(this).inflate(R.layout.floating_menu, null);

        int layoutFlag;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            layoutFlag = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
        } else {
            layoutFlag = WindowManager.LayoutParams.TYPE_PHONE;
        }

        final WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT);

        params.gravity = Gravity.TOP | Gravity.LEFT;
        params.x = 0;
        params.y = 100;

        mWindowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        mWindowManager.addView(mFloatingView, params);

        collapsedView = mFloatingView.findViewById(R.id.collapsed_view);
        expandedView = mFloatingView.findViewById(R.id.expanded_view);

        setupInteractions(params);
    }

    private void setupInteractions(final WindowManager.LayoutParams params) {
        // Dragging listener
        View.OnTouchListener dragListener = new View.OnTouchListener() {
            private int initialX;
            private int initialY;
            private float initialTouchX;
            private float initialTouchY;
            private boolean isDragging;

            @Override
            public boolean onTouch(View v, MotionEvent event) {
                switch (event.getAction()) {
                    case MotionEvent.ACTION_DOWN:
                        initialX = params.x;
                        initialY = params.y;
                        initialTouchX = event.getRawX();
                        initialTouchY = event.getRawY();
                        isDragging = false;
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        int diffX = (int) (event.getRawX() - initialTouchX);
                        int diffY = (int) (event.getRawY() - initialTouchY);
                        if (Math.abs(diffX) > 10 || Math.abs(diffY) > 10) {
                            isDragging = true;
                        }
                        params.x = initialX + diffX;
                        params.y = initialY + diffY;
                        mWindowManager.updateViewLayout(mFloatingView, params);
                        return true;
                    case MotionEvent.ACTION_UP:
                        if (!isDragging && v == collapsedView) {
                            // Expand the menu
                            collapsedView.setVisibility(View.GONE);
                            expandedView.setVisibility(View.VISIBLE);
                        }
                        return true;
                }
                return false;
            }
        };

        // Attach dragging
        collapsedView.setOnTouchListener(dragListener);
        View header = mFloatingView.findViewById(R.id.header);
        header.setOnTouchListener(dragListener);

        // Minimize Button
        mFloatingView.findViewById(R.id.btn_minimize).setOnClickListener(v -> {
            expandedView.setVisibility(View.GONE);
            collapsedView.setVisibility(View.VISIBLE);
        });

        // Close Button (completely kill)
        mFloatingView.findViewById(R.id.btn_close).setOnClickListener(v -> stopSelf());

        // Accordion functionality
        View tvCategory1 = mFloatingView.findViewById(R.id.tv_category1);
        View containerCategory1 = mFloatingView.findViewById(R.id.container_category1);
        tvCategory1.setOnClickListener(v -> {
            boolean isVisible = containerCategory1.getVisibility() == View.VISIBLE;
            containerCategory1.setVisibility(isVisible ? View.GONE : View.VISIBLE);
        });

        View tvCategory2 = mFloatingView.findViewById(R.id.tv_category2);
        View containerCategory2 = mFloatingView.findViewById(R.id.container_category2);
        tvCategory2.setOnClickListener(v -> {
            boolean isVisible = containerCategory2.getVisibility() == View.VISIBLE;
            containerCategory2.setVisibility(isVisible ? View.GONE : View.VISIBLE);
        });

        // Sliders
        SeekBar seekSpeed = mFloatingView.findViewById(R.id.seekbar_speed);
        TextView tvSpeed = mFloatingView.findViewById(R.id.tv_speed);
        seekSpeed.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                tvSpeed.setText("Speed: " + progress + "%");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        SeekBar seekJump = mFloatingView.findViewById(R.id.seekbar_jump);
        TextView tvJump = mFloatingView.findViewById(R.id.tv_jump);
        seekJump.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                tvJump.setText("Jump Height: " + progress + "%");
            }
            @Override public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override public void onStopTrackingTouch(SeekBar seekBar) {}
        });
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mFloatingView != null) {
            mWindowManager.removeView(mFloatingView);
        }
    }
}
