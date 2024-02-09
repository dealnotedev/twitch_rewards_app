import 'package:flutter/material.dart';
import 'package:twitch_listener/generated/assets.dart';

class ObsWidget extends StatefulWidget {
  const ObsWidget({super.key});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ObsWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF363A46),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            Assets.assetsIcObs32dp,
            filterQuality: FilterQuality.medium,
            width: 32,
            height: 32,
          ),
          const SizedBox(
            width: 16,
          ),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OBS Connection',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(
                height: 8,
              ),
              Row(
                children: [
                  Expanded(
                      child: _createSearchWidget(context, hint: 'Address')),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                      child: _createSearchWidget(context, hint: 'Password'))
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                    onPressed: () {}, child: const Text('Apply')),
              )
            ],
          ))
        ],
      ),
    );
  }

  Widget _createSearchWidget(BuildContext context, {required String hint}) {
    return TextField(
      onChanged: (value) {},
      maxLines: 1,
      style: const TextStyle(
        fontSize: 14,
      ),
      decoration: InputDecoration(
          hintStyle: const TextStyle(fontSize: 14),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          fillColor: const Color(0xFF272E37),
          filled: true,
          isDense: true,
          hintText: hint),
    );
  }
}
