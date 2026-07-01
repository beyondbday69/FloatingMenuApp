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
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.SeekBar;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.util.ArrayList;
import java.util.List;

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

        // Close Button (Now Minimizes)
        mFloatingView.findViewById(R.id.btn_close).setOnClickListener(v -> {
            expandedView.setVisibility(View.GONE);
            collapsedView.setVisibility(View.VISIBLE);
        });

        // Accordion functionality Category 1
        View tvCategory1 = mFloatingView.findViewById(R.id.tv_category1);
        View containerCategory1 = mFloatingView.findViewById(R.id.container_category1);
        tvCategory1.setOnClickListener(v -> {
            boolean isVisible = containerCategory1.getVisibility() == View.VISIBLE;
            containerCategory1.setVisibility(isVisible ? View.GONE : View.VISIBLE);
        });

        // Accordion functionality Category 2
        View tvCategory2 = mFloatingView.findViewById(R.id.tv_category2);
        View containerCategory2 = mFloatingView.findViewById(R.id.container_category2);
        tvCategory2.setOnClickListener(v -> {
            boolean isVisible = containerCategory2.getVisibility() == View.VISIBLE;
            containerCategory2.setVisibility(isVisible ? View.GONE : View.VISIBLE);
        });

        // Accordion functionality Category 3 (Skin Selector)
        View tvCategory3 = mFloatingView.findViewById(R.id.tv_category3);
        View containerCategory3 = mFloatingView.findViewById(R.id.container_category3);
        tvCategory3.setOnClickListener(v -> {
            boolean isVisible = containerCategory3.getVisibility() == View.VISIBLE;
            containerCategory3.setVisibility(isVisible ? View.GONE : View.VISIBLE);
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

        // Skin Selector Spinner
        Spinner spinnerSkins = mFloatingView.findViewById(R.id.spinner_skins);
        if (spinnerSkins != null) {
            List<String> displaySkinsList = new ArrayList<>();
            List<String> rawWriteList = new ArrayList<>();
            File skinsFile = new File("/sdcard/skins_list.ini");
            
            if (skinsFile.exists()) {
                try {
                    BufferedReader br = new BufferedReader(new FileReader(skinsFile));
                    String line;
                    while ((line = br.readLine()) != null) {
                        int eqIdx = line.indexOf('=');
                        if (eqIdx != -1) {
                            displaySkinsList.add(line.substring(0, eqIdx).trim());
                            rawWriteList.add(line.substring(eqIdx + 1).trim());
                        }
                    }
                    br.close();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }

            if (displaySkinsList.isEmpty()) {
                // Defaults if file not found or empty
                String[] defaults = {
                    "M416 Glacier|M416=101004008",
                    "AKM Hellfire|AKM=101001005",
                    "AWM Godzilla|AWM=103003009",
                    "UAZ Aegis|UAZ_1908001=190800101"
                };
                for (String d : defaults) {
                    String[] parts = d.split("\\|");
                    displaySkinsList.add(parts[0]);
                    rawWriteList.add(parts[1]);
                }
            }

            ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, displaySkinsList);
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
            spinnerSkins.setAdapter(adapter);

            Button btnApplySkins = mFloatingView.findViewById(R.id.btn_apply_skins);
            if (btnApplySkins != null) {
                btnApplySkins.setOnClickListener(v -> {
                    int pos = spinnerSkins.getSelectedItemPosition();
                    if (pos >= 0 && pos < rawWriteList.size()) {
                        String toWrite = rawWriteList.get(pos) + "\n";
                        try {
                            File dir = new File("/sdcard/Documents/");
                            if (!dir.exists()) dir.mkdirs();
                            File file = new File(dir, "SKINS.ini");
                            FileOutputStream fos = new FileOutputStream(file, false); // false = overwrite
                            fos.write(toWrite.getBytes());
                            fos.close();
                            Toast.makeText(FloatingMenuService.this, "Skin saved to /sdcard/Documents/SKINS.ini!", Toast.LENGTH_SHORT).show();
                        } catch (Exception e) {
                            Toast.makeText(FloatingMenuService.this, "Error: Storage Permission denied!", Toast.LENGTH_LONG).show();
                        }
                    }
                });
            }
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mFloatingView != null) {
            mWindowManager.removeView(mFloatingView);
        }
    }
}
